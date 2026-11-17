---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Block File Deletion With A Localhost seccomp Profile Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-02-02" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Write The Profile

A seccomp profile is a JSON file that tells the kernel what to do with each system call of the container. Check the node first. The kubelet seccomp directory does not exist yet:

```sh
node_name="astro-ats-033-lab-040-02-02-control-plane"
podman exec "$node_name" ls -R /var/lib/kubelet/seccomp
```

```text
ls: cannot access '/var/lib/kubelet/seccomp': No such file or directory
```

A seccomp filter decides on the system call, not on the command name, so the profile must name every call that removes a file or a directory. `rm` uses `unlinkat` or `unlink`, and `rmdir` removes directories. The default action stays `SCMP_ACT_ALLOW`, because the pod must keep creating and reading files.

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

`errnoRet: 1` makes the kernel return error number 1, `EPERM`, which programs print as `Operation not permitted`.

## Place The Profile On The Node

The kubelet reads `Localhost` profiles only from `/var/lib/kubelet/seccomp` on the node where the pod runs. Create the folder and copy the file into the node container:

```sh
podman exec "$node_name" mkdir -p /var/lib/kubelet/seccomp/profiles
podman cp block-delete.json "$node_name:/var/lib/kubelet/seccomp/profiles/block-delete.json"
podman exec "$node_name" ls -l /var/lib/kubelet/seccomp/profiles
```

```text
total 4
-rw-r--r--. 1 root root 175 Nov 17 22:00 block-delete.json
```

## Create The Pod

The value of `localhostProfile` is relative to the kubelet seccomp directory, so the file above is `profiles/block-delete.json`.

Save this as `pod-no-delete.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-delete
  namespace: starfleet-033-040-02-02
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

Apply it:

```sh
kubectl apply -f pod-no-delete.yaml
```

```text
pod/no-delete created
```

Then wait until the pod is ready:

```sh
kubectl -n starfleet-033-040-02-02 wait --for=condition=Ready pod/no-delete --timeout=180s
```

```text
pod/no-delete condition met
```

## Verify The Result

The value `2` in the `Seccomp:` line means the container runtime installed a filter on the main process:

```sh
kubectl -n starfleet-033-040-02-02 exec no-delete -- grep Seccomp: /proc/1/status
```

```text
Seccomp:	2
```

Writing and reading a file use other system calls, so they work:

```sh
kubectl -n starfleet-033-040-02-02 exec no-delete -- sh -c 'echo kept > /tmp/keep && cat /tmp/keep'
```

```text
kept
```

The next two commands are expected to fail, so run each on its own:

```sh
kubectl -n starfleet-033-040-02-02 exec no-delete -- rm /tmp/keep
```

```text
rm: can't remove '/tmp/keep': Operation not permitted
command terminated with exit code 1
```

```sh
kubectl -n starfleet-033-040-02-02 exec no-delete -- rmdir /tmp
```

```text
rmdir: '/tmp': Operation not permitted
command terminated with exit code 1
```

The process runs as root, which may normally delete these files. The kernel refused the system call because of the seccomp rule, before it checked any permission.

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-02-02`.

## Common pitfalls

> [!WARNING]
> - Blocking only `unlink`. Many programs, `rm` among them, can use `unlinkat` instead, so the file may still be removed.
> - Writing the full node path in `localhostProfile`. The value is relative to `/var/lib/kubelet/seccomp`.
> - Using `SCMP_ACT_ERRNO` as the default action. Almost every system call then fails, and the container cannot start.
