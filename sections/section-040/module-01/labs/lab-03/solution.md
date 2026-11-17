---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Harden A Deployment To The Restricted Pod Security Level Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-01-03" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect The Starting Point

Check who the process runs as before you change anything:

```sh
kubectl -n starfleet-033-040-01-03 exec deploy/scout -- id
```

```text
uid=0(root) gid=0(root) groups=0(root),10(wheel)
```

Pod Security Admission is the admission controller in the API server that checks pods against the Pod Security levels. A server-side dry run of the namespace label asks it which running pods would break the `restricted` level, without saving the label:

```sh
kubectl label --dry-run=server --overwrite namespace starfleet-033-040-01-03 pod-security.kubernetes.io/enforce=restricted
```

```text
Warning: existing pods in namespace "starfleet-033-040-01-03" violate the new PodSecurity enforce level "restricted:latest"
Warning: scout-8569fccfdc-gj2pr: allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
namespace/starfleet-033-040-01-03 labeled (server dry run)
```

The second warning lists the four fields to fix. The read-only root filesystem is not part of the `restricted` level, so the dry run does not mention it.

## See Why A Read-Only Root Needs A Volume

It is tempting to set only `readOnlyRootFilesystem: true`. This JSON patch does exactly that, so you can see what happens:

```sh
kubectl -n starfleet-033-040-01-03 patch deployment scout --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{"readOnlyRootFilesystem":true}}]'
```

```text
deployment.apps/scout patched
```

Wait about 30 seconds and list the pods:

```sh
kubectl -n starfleet-033-040-01-03 get pods
kubectl -n starfleet-033-040-01-03 logs -l app=scout --tail=5
```

```text
NAME                     READY   STATUS             RESTARTS      AGE
scout-5bdb5d46c-kl6xv    0/1     CrashLoopBackOff   2 (17s ago)   30s
scout-8569fccfdc-ktwq7   1/1     Running            0             77s
sh: can't create /tmp/heartbeat: Read-only file system
```

The last line comes from the log of the crashing pod. The new pod crashes because `/tmp` is part of the root filesystem, which is now read-only. The old pod keeps running, because the Deployment does not remove it until the new pod is ready. The fix is to mount a writable `emptyDir` volume at `/tmp`. An `emptyDir` is an empty directory that the kubelet creates for the pod on the node and deletes with the pod.

## Apply The Hardened Deployment

The file below keeps the name, image, command and readiness probe, and adds the security settings. At pod level, `runAsNonRoot`, `runAsUser` and `runAsGroup` set the identity, and `seccompProfile` sets the container runtime's default seccomp filter. At container level, `allowPrivilegeEscalation`, `readOnlyRootFilesystem` and `capabilities` exist only there.

Save this as `deployment-scout.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout
  namespace: starfleet-033-040-01-03
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scout
  template:
    metadata:
      labels:
        app: scout
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: scout
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - while date > /tmp/heartbeat; do sleep 5; done
        readinessProbe:
          exec:
            command:
            - cat
            - /tmp/heartbeat
          periodSeconds: 5
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: scratch
          mountPath: /tmp
      volumes:
      - name: scratch
        emptyDir: {}
```

Apply it:

```sh
kubectl apply -f deployment-scout.yaml
```

```text
deployment.apps/scout configured
```

Then check the result. The rollout finishes when the new pod is ready:

```sh
kubectl -n starfleet-033-040-01-03 rollout status deployment/scout --timeout=180s
```

```text
Waiting for deployment "scout" rollout to finish: 0 out of 1 new replicas have been updated...
Waiting for deployment "scout" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "scout" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "scout" rollout to finish: 1 old replicas are pending termination...
deployment "scout" successfully rolled out
```

The old pods take a few seconds to stop. After that, one pod is left:

```sh
kubectl -n starfleet-033-040-01-03 get pods
```

```text
NAME                    READY   STATUS    RESTARTS   AGE
scout-956bcdff7-pd9ns   1/1     Running   0          41s
```

## Verify The Result

The process now runs as user ID 1000:

```sh
kubectl -n starfleet-033-040-01-03 exec deploy/scout -- id
```

```text
uid=1000 gid=1000 groups=1000
```

The next command is expected to fail, so run it on its own:

```sh
kubectl -n starfleet-033-040-01-03 exec deploy/scout -- touch /scout-root-check
```

```text
touch: /scout-root-check: Read-only file system
command terminated with exit code 1
```

The heartbeat still works, because `/tmp` is the `emptyDir` volume:

```sh
kubectl -n starfleet-033-040-01-03 exec deploy/scout -- sh -c 'cat /tmp/heartbeat && ls -ld /tmp'
```

```text
Tue Nov 17 21:57:18 UTC 2026
drwxrwxrwx    2 root     root            23 Nov 17 21:56 /tmp
```

The directory is owned by root, but its mode is `drwxrwxrwx`, so every user can write to it. This volume therefore needs no `fsGroup`. Some volume types are not writable for every user, and for those `fsGroup` sets the group that may write.

Run the dry run again:

```sh
kubectl label --dry-run=server --overwrite namespace starfleet-033-040-01-03 pod-security.kubernetes.io/enforce=restricted
```

```text
namespace/starfleet-033-040-01-03 labeled (server dry run)
```

No warning is printed, so Pod Security Admission found no violation. The label was not saved, because the command used `--dry-run=server`.

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-01-03`.

## Common pitfalls

> [!WARNING]
> - Setting `runAsNonRoot: true` without `runAsUser`. The busybox image starts as root, so the kubelet refuses to start the container with `CreateContainerConfigError`.
> - Making the root filesystem read-only without a volume for the paths the application writes. The container crashes with `Read-only file system`.
> - Running the dry run while an old pod is still terminating. The warning then names the old pod, so wait until only the new pod is left.
