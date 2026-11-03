---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Guided Practice: Apply A Localhost seccomp Profile

Use a host shell with this playground's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the graded labs.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-040-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-040-02" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the playground refuses a different context.

Name the node, which is a Podman container, and look at the starting state. No custom profile exists yet.

```sh
node_name="astro-ats-033-playground-040-02-control-plane"
kubectl -n starfleet get pods
podman exec "$node_name" ls /var/lib/kubelet/seccomp
```

Save this as `block-rename.json`:

```json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["rename", "renameat", "renameat2"],
      "action": "SCMP_ACT_ERRNO",
      "errnoRet": 1
    }
  ]
}
```

Copy it into the kubelet seccomp directory of the node:

```sh
podman exec "$node_name" mkdir -p /var/lib/kubelet/seccomp/profiles
podman cp block-rename.json "$node_name:/var/lib/kubelet/seccomp/profiles/block-rename.json"
```

Save this as `pod-seccomp-block-rename.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-rename
  namespace: starfleet
spec:
  restartPolicy: Never
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/block-rename.json
  containers:
  - name: shell
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
```

Apply it:

```sh
kubectl apply -f pod-seccomp-block-rename.yaml
```

Then check the result. The last command is expected to fail, so run it on its own:

```sh
kubectl -n starfleet wait --for=condition=Ready pod/no-rename --timeout=180s
kubectl -n starfleet exec no-rename -- grep Seccomp: /proc/1/status
kubectl -n starfleet exec no-rename -- sh -c 'echo data > /tmp/a && cp /tmp/a /tmp/b && cat /tmp/b'
kubectl -n starfleet exec no-rename -- mv /tmp/a /tmp/c
```

Create Pod `no-rename` that runs BusyBox with the `Localhost` seccomp profile `profiles/block-rename.json`. The profile allows every syscall except `rename`, `renameat` and `renameat2`, which return `EPERM`. Copying a file must work and moving it must fail with `Operation not permitted`. Keep the sleeping process running.

## Common pitfalls

> [!WARNING]
> - **Writing the whole path in `localhostProfile`.** The value is relative to `/var/lib/kubelet/seccomp`.
> - **Naming only one rename variant.** The block must name `rename`, `renameat` and `renameat2`.
> - **Copying the profile after the pod.** Place the file on the node first, or the container does not start.
