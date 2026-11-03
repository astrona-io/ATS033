---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Block File Deletion With A Localhost seccomp Profile Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-02-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect And Explain

Check what exists on the node. The seccomp directory has no profile for this task:

```sh
node_name="astro-ats-033-lab-040-02-01-control-plane"
podman exec "$node_name" ls -R /var/lib/kubelet/seccomp
kubectl -n starfleet get pods
```

A seccomp filter decides on the syscall, so the profile must name every variant that removes a file or a directory. `rm` calls `unlinkat` or `unlink`, and `rmdir` removes directories. The default action stays `SCMP_ACT_ALLOW`, because the pod must keep creating and reading files.

Save this as `block-delete.json`:

```json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["unlink", "unlinkat", "rmdir"],
      "action": "SCMP_ACT_ERRNO",
      "errnoRet": 1
    }
  ]
}
```

Copy it into the kubelet seccomp directory of the node:

```sh
podman exec "$node_name" mkdir -p /var/lib/kubelet/seccomp/profiles
podman cp block-delete.json "$node_name:/var/lib/kubelet/seccomp/profiles/block-delete.json"
```

Save this as `pod-seccomp-block-delete.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-delete
  namespace: starfleet
spec:
  restartPolicy: Never
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/block-delete.json
  containers:
  - name: shell
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
```

Apply the required change:

```sh
kubectl apply -f pod-seccomp-block-delete.yaml
```

## Verify The Result

Observe the actual result. A denied operation returns a nonzero status when the control works. Run denial checks separately from a shell sequence that stops on the first nonzero status.

```sh
kubectl -n starfleet wait --for=condition=Ready pod/no-delete --timeout=180s
kubectl -n starfleet exec no-delete -- grep Seccomp: /proc/1/status
kubectl -n starfleet exec no-delete -- sh -c 'echo kept > /tmp/keep; cat /tmp/keep'
kubectl -n starfleet exec no-delete -- rm /tmp/keep
```

Write a seccomp profile `block-delete.json` with `defaultAction` `SCMP_ACT_ALLOW` and one rule that returns `SCMP_ACT_ERRNO` for the syscalls `unlink`, `unlinkat` and `rmdir`. Place it on the node at `/var/lib/kubelet/seccomp/profiles/block-delete.json`. The node is the container `astro-ats-033-lab-040-02-01-control-plane`, and `podman cp` copies a file into it. Create Pod `no-delete` in `starfleet` that runs BusyBox with `seccompProfile` type `Localhost` and `localhostProfile` `profiles/block-delete.json`. Writing a file must work and deleting it with `rm` must fail with `Operation not permitted`. Keep the sleeping process running.

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-02-01`.

## Common pitfalls

> [!WARNING]
> A profile must exist on the node before the pod is created, and `localhostProfile` is relative to `/var/lib/kubelet/seccomp`. Name every variant of the syscall. Do not use `Unconfined` to make an error disappear.
