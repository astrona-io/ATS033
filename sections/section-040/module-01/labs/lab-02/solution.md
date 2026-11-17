---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Load An AppArmor Profile And Attach It To A Pod Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-01-02" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

This walkthrough has no command output. The lab needs a host kernel with AppArmor, and it has not yet run on such a host. Each step says what a correct result contains, so you can compare your own output with it.

## Write And Load The Profile

An AppArmor profile is a text file. The word after `profile` is the name that a pod uses. The lines `file,`, `network,` and `capability,` allow those groups of operations. The line `deny /tmp/** w,` denies write access below `/tmp`, and a `deny` rule wins over an allow rule. The flag `attach_disconnected` lets the profile apply to paths that a container sees differently from the host.

Save this as `k8s-deny-tmp-write`:

```text
#include <tunables/global>

profile k8s-deny-tmp-write flags=(attach_disconnected) {
  #include <abstractions/base>

  file,
  network,
  capability,

  deny /tmp/** w,
}
```

A profile lives in the kernel, and every node has its own kernel list. The pod can run on either node, so copy the file to both nodes and load it with `apparmor_parser -r`. The option `-r` loads the profile, or replaces it when it is already loaded. Without `-C` it loads in enforce mode:

```sh
for node_name in astro-ats-033-lab-040-01-02-control-plane astro-ats-033-lab-040-01-02-worker; do
  podman cp k8s-deny-tmp-write "$node_name:/etc/apparmor.d/k8s-deny-tmp-write"
  podman exec "$node_name" apparmor_parser -r /etc/apparmor.d/k8s-deny-tmp-write
done
```

The commands print nothing when they work. Check the kernel list on both nodes. Each node prints one line, `k8s-deny-tmp-write (enforce)`:

```sh
for node_name in astro-ats-033-lab-040-01-02-control-plane astro-ats-033-lab-040-01-02-worker; do
  podman exec "$node_name" grep k8s-deny-tmp-write /sys/kernel/security/apparmor/profiles
done
```

## Create The Pod

The field `appArmorProfile` in the container `securityContext` selects the profile. The type `Localhost` means a profile that is already loaded on the node, and `localhostProfile` holds the profile name, not a file path.

Save this as `pod-scout.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: scout
  namespace: starfleet-033-040-01-02
spec:
  restartPolicy: Never
  containers:
  - name: scout
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: k8s-deny-tmp-write
```

Apply it:

```sh
kubectl apply -f pod-scout.yaml
```

Then check the result. The wait ends with a line that says the pod met the `Ready` condition:

```sh
kubectl -n starfleet-033-040-01-02 wait --for=condition=Ready pod/scout --timeout=180s
```

## Verify The Result

The kernel shows the profile of a process in `/proc/<pid>/attr/current`. For the main process of `scout`, a correct result is the profile name and the mode in parentheses, `k8s-deny-tmp-write (enforce)`:

```sh
kubectl -n starfleet-033-040-01-02 exec scout -- cat /proc/1/attr/current
```

The last check must fail. The container runs as root, so file permissions allow the write; only the AppArmor rule stops it. A correct result is a `Permission denied` message from `touch` and a non-zero exit code:

```sh
kubectl -n starfleet-033-040-01-02 exec scout -- touch /tmp/scout-check
```

AppArmor returns `Permission denied` (the error `EACCES`), while a seccomp rule usually returns `Operation not permitted`. The message tells you which control stopped the call.

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-01-02`.

## Common pitfalls

> [!WARNING]
> - Loading the profile on one node only. When the scheduler places the pod on the other node, the container does not start.
> - Writing the file name or a path in `localhostProfile`. The field takes the profile name from the line that starts with `profile`.
> - Loading with `-C`. The profile is then in complain mode, and the write to `/tmp` is only logged.
