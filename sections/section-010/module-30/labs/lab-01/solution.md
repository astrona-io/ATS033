---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Remove Host Access From A Workload Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-03-01" || exit 1
```

## Inspect the starting pod

The first command prints the three pod template fields that give host access: `hostNetwork`, `hostPID` and the container's `privileged` flag. The second command shows the pod address next to its node:

```sh
kubectl -n starfleet-033-010-03-01 get deployment beacon -o jsonpath='{.spec.template.spec.hostNetwork} {.spec.template.spec.hostPID} {.spec.template.spec.containers[0].securityContext.privileged}{"\n"}'
kubectl -n starfleet-033-010-03-01 get pods -l app=beacon -o wide
```

```text
true true true
NAME                      READY   STATUS    RESTARTS   AGE   IP            NODE                                 NOMINATED NODE   READINESS GATES
beacon-5f79969c64-ktt45   1/1     Running   0          27s   10.89.0.105   astro-ats-033-lab-010-03-01-worker   <none>           <none>
```

All three fields are `true`. The pod IP address `10.89.0.105` is the address of the node, because `hostNetwork: true` puts the container in the network namespace of the node. Your pod name and addresses will differ.

Because of `hostPID: true`, the container also shares the process ID (PID) namespace of the node, so `ps` in the container lists the processes of the node. `id` shows the user the container runs as:

```sh
kubectl -n starfleet-033-010-03-01 exec deploy/beacon -- sh -c 'ps -o pid,comm | grep -E "kubelet|containerd" | head -3; id'
```

```text
  123 containerd
  203 kubelet
  264 containerd-shim
uid=0(root) gid=0(root) groups=0(root),10(wheel)
```

The container sees `kubelet` and `containerd` and runs as root (UID 0).

## Rewrite the Deployment

The new pod template drops the host namespace fields and the `hostPath` volume. It adds an `emptyDir` volume, which the kubelet creates empty for the pod and deletes with the pod. The `securityContext` of the container sets the user and blocks privilege. `readOnlyRootFilesystem: true` makes the image filesystem read-only, so the container can write only to mounted volumes.

Save this as `deployment-beacon.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: beacon
  namespace: starfleet-033-010-03-01
spec:
  replicas: 1
  selector:
    matchLabels:
      app: beacon
  template:
    metadata:
      labels:
        app: beacon
    spec:
      containers:
      - name: beacon
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep 3600
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 10001
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: scratch
          mountPath: /scratch
      volumes:
      - name: scratch
        emptyDir: {}
```

Apply it:

```sh
kubectl apply -f deployment-beacon.yaml
```

`kubectl apply` replaces the whole pod template with this file, so the fields that the file leaves out (`hostNetwork`, `hostPID`, the `host-log` volume) are removed. `kubectl edit` works too, but there you must delete each field by hand.

Then check the result. The Deployment controller creates a new ReplicaSet and replaces the old pod:

```sh
kubectl -n starfleet-033-010-03-01 rollout status deployment/beacon --timeout=120s
kubectl -n starfleet-033-010-03-01 get pods -l app=beacon -o wide
```

```text
Waiting for deployment "beacon" rollout to finish: 0 out of 1 new replicas have been updated...
Waiting for deployment "beacon" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "beacon" rollout to finish: 1 old replicas are pending termination...
deployment "beacon" successfully rolled out
NAME                      READY   STATUS        RESTARTS   AGE   IP            NODE                                 NOMINATED NODE   READINESS GATES
beacon-5487874b69-thgp9   1/1     Running       0          0s    10.244.1.2    astro-ats-033-lab-010-03-01-worker   <none>           <none>
beacon-5f79969c64-ktt45   1/1     Terminating   0          37s   10.89.0.105   astro-ats-033-lab-010-03-01-worker   <none>           <none>
```

The new pod has the address `10.244.1.2` from the pod network, not the node address. The old pod is still terminating; it disappears after a few seconds.

## Test the new pod

The fields only matter if the running container behaves as they say. Check the user, the process list, a write to `/` and a write to `/scratch`:

```sh
kubectl -n starfleet-033-010-03-01 exec deploy/beacon -- id
kubectl -n starfleet-033-010-03-01 exec deploy/beacon -- ps -o pid,comm
kubectl -n starfleet-033-010-03-01 exec deploy/beacon -- touch /test-file
kubectl -n starfleet-033-010-03-01 exec deploy/beacon -- touch /scratch/test-file
kubectl -n starfleet-033-010-03-01 exec deploy/beacon -- ls -l /scratch
```

```text
uid=10001 gid=0(root) groups=0(root)
PID   COMMAND
    1 sleep
   20 ps
touch: /test-file: Read-only file system
command terminated with exit code 1
-rw-r--r--    1 10001    root             0 Nov 17 21:59 test-file
```

The container runs as UID 10001. It sees only its own processes, because it has its own PID namespace. The write to `/` fails with `Read-only file system`, and the write to the `emptyDir` at `/scratch` works. The output of `ls -l` is shortened: the line `total 0` is left out. The group is still 0, because the template sets no `runAsGroup`; the task does not require it, but `runAsGroup` is a good addition in a real workload.

## Common pitfalls

> [!WARNING]
> - **Setting `hostNetwork: false` and keeping `hostPID: true`.** Each host namespace field is separate. Remove all three.
> - **`readOnlyRootFilesystem` without a writable volume.** Many programs need a temporary directory. Mount an `emptyDir` where the program writes, or it crashes at start.
> - **`runAsNonRoot: true` without a user.** The busybox image runs as root by default, so the kubelet refuses to start the container with `CreateContainerConfigError`. Set `runAsUser` to a non-zero UID.
> - **Patching the template with `kubectl patch` and forgetting the volume mount.** If you remove the `host-log` volume but keep its `volumeMounts` entry, the API server rejects the Deployment.
