---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Load An AppArmor Profile And Attach It To A Pod Solution

The lab runs in a VM (virtual machine) with a one-node Kubernetes cluster built with kubeadm. Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-040-01-02
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-lab-040-01-02
```

You are logged in as the `student` user. The files under `/etc/apparmor.d` and the kernel profile list belong to root, so the node commands below use `sudo`. The output on this page comes from a run on 2026-11-18.

## Write And Load The Profile

An AppArmor profile is a text file. The word after `profile` is the name that a pod uses. The lines `file,`, `network,` and `capability,` allow those groups of operations. The line `deny /tmp/** w,` denies write access below `/tmp`, and a `deny` rule wins over an allow rule. The flag `attach_disconnected` lets the profile apply to paths that a container sees differently from the host.

The line `signal (receive) peer=runc,` lets the container runtime (`runc`) send signals to the container. When the pod is deleted, `runc` sends the `kill` signal. Without this line the kernel denies that signal, and the pod stays in `Terminating`.

Save this as `k8s-deny-tmp-write`:

```text
#include <tunables/global>

profile k8s-deny-tmp-write flags=(attach_disconnected) {
  #include <abstractions/base>

  file,
  network,
  capability,
  # Let the container runtime (runc) stop the container.
  signal (receive) peer=runc,

  deny /tmp/** w,
}
```

A profile lives in the kernel of the node, and this cluster has one node: the VM. Copy the file to `/etc/apparmor.d` and load it with `apparmor_parser -r`. The option `-r` loads the profile, or replaces it when it is already loaded. Without `-C` it loads in enforce mode:

```sh
sudo cp k8s-deny-tmp-write /etc/apparmor.d/k8s-deny-tmp-write
sudo apparmor_parser -r /etc/apparmor.d/k8s-deny-tmp-write
```

Both commands print nothing when they work. Then check the kernel list:

```sh
sudo grep k8s-deny-tmp-write /sys/kernel/security/apparmor/profiles
```

```text
k8s-deny-tmp-write (enforce)
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

```text
pod/scout created
```

Then check the result:

```sh
kubectl -n starfleet-033-040-01-02 wait --for=condition=Ready pod/scout --timeout=180s
```

```text
pod/scout condition met
```

## Verify The Result

The kernel shows the profile of a process in `/proc/<pid>/attr/current`. For the main process of `scout`, it shows the profile name and the mode in parentheses:

```sh
kubectl -n starfleet-033-040-01-02 exec scout -- cat /proc/1/attr/current
```

```text
k8s-deny-tmp-write (enforce)
```

The last check must fail. The container runs as root, so file permissions allow the write. Only the AppArmor rule stops it:

```sh
kubectl -n starfleet-033-040-01-02 exec scout -- touch /tmp/scout-check
```

```text
touch: /tmp/scout-check: Permission denied
command terminated with exit code 1
```

AppArmor returns `Permission denied` (the error `EACCES`), while a seccomp rule usually returns `Operation not permitted`. The message tells you which control stopped the call.

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-01-02`.

## Common pitfalls

> [!WARNING]
> - Forgetting `sudo`. As the `student` user, `apparmor_parser` and the read of the kernel profile list fail.
> - Writing the file name or a path in `localhostProfile`. The field takes the profile name from the line that starts with `profile`.
> - Leaving out `signal (receive) peer=runc,`. The pod starts, but when it is deleted it stays in `Terminating`, because the kernel denies the stop signal from `runc`.
> - Loading with `-C`. The profile is then in complain mode, which the grader does not accept.
