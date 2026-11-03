---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Harden A Workload With seccomp, Capabilities And A Read-Only Filesystem Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-capstone-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect And Explain

Look at the profile the security team placed on the node and at the current Deployment:

```sh
node_name="astro-ats-033-lab-040-capstone-01-control-plane"
podman exec "$node_name" ls /var/lib/kubelet/seccomp/profiles
podman exec "$node_name" cat /var/lib/kubelet/seccomp/profiles/cargo-guard.json
kubectl -n starfleet get deployment cargo -o yaml
```

Three controls from the section combine here. The kernel boundary is the `Localhost` seccomp profile, and the value is the path relative to `/var/lib/kubelet/seccomp`. The privilege boundary is `privileged: false`, `allowPrivilegeEscalation: false` and all capabilities dropped. The filesystem boundary is a read-only root filesystem with a writable `emptyDir` that the non-root user can write because of `fsGroup`. If the profile name has a typo, the pod stays in `CreateContainerError` and the pod events name the file.

Save this as `deployment-cargo.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cargo
  namespace: starfleet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cargo
  template:
    metadata:
      labels:
        app: cargo
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: Localhost
          localhostProfile: profiles/cargo-guard.json
      containers:
      - name: cargo
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - sleep 3600
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
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

Apply the required change:

```sh
kubectl apply -f deployment-cargo.yaml
```

## Verify The Result

Observe the actual result. A denied operation returns a nonzero status when the control works. Run denial checks separately from a shell sequence that stops on the first nonzero status.

```sh
kubectl -n starfleet rollout status deployment/cargo --timeout=180s
kubectl -n starfleet exec deploy/cargo -- id -u
kubectl -n starfleet exec deploy/cargo -- grep -E 'Seccomp:|NoNewPrivs|CapBnd' /proc/1/status
kubectl -n starfleet exec deploy/cargo -- sh -c 'printf allowed > /scratch/result; cat /scratch/result'
kubectl -n starfleet exec deploy/cargo -- sh -c 'printf denied > /root-file'
kubectl -n starfleet exec deploy/cargo -- ln -s /scratch/result /scratch/link
```

Rewrite Deployment `cargo` in `starfleet` and keep its name, selector, image, command and one replica. Its pod must run as user and group 1000 with `runAsNonRoot: true`, `fsGroup: 1000` and the `Localhost` seccomp profile `profiles/cargo-guard.json`. Its container `cargo` must set `privileged: false`, `allowPrivilegeEscalation: false` and `readOnlyRootFilesystem: true`, and drop `ALL` capabilities without adding any back. An `emptyDir` volume `scratch` must be mounted at `/scratch`. In the running pod, `Seccomp` must be `2`, `NoNewPrivs` must be `1` and `CapBnd` must be all zeros. Writing in `/scratch` must work, writing `/root-file` must fail, and `ln -s` must fail with `Operation not permitted`. Do not use `Unconfined`. The Deployment rollout must be complete.

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-capstone-01`.

## Common pitfalls

> [!WARNING]
> If the pod does not start, read its events first, because the container was never created and has no log. Do not replace the profile with `Unconfined`. Container-only fields belong under `containers[].securityContext`, and a read-only root filesystem needs the `emptyDir` and `fsGroup` to stay writable where the application needs it.
