---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Install And Use A Localhost seccomp Profile Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-01-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect The Node

A `Localhost` seccomp profile is a JSON file that the kubelet reads from its seccomp directory, `/var/lib/kubelet/seccomp`, when it creates the container. The kubelet never looks anywhere else, so a profile in another folder is invisible to it. Start by looking at both places on the node:

```sh
node_name="astro-ats-033-lab-040-01-01-control-plane"
podman exec "$node_name" ls -l /opt/course/seccomp /var/lib/kubelet/seccomp
```

```text
ls: cannot access '/var/lib/kubelet/seccomp': No such file or directory
/opt/course/seccomp:
total 4
-rw-r--r--. 1 root root 184 Nov 17 21:44 scout-guard.json
```

The profile exists, and the kubelet seccomp directory does not exist yet. Read the profile before you install it, so you know what to test afterwards:

```sh
podman exec "$node_name" cat /opt/course/seccomp/scout-guard.json
```

```text
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["mkdir", "mkdirat", "mknod", "mknodat"],
      "action": "SCMP_ACT_ERRNO",
      "errnoRet": 1
    }
  ]
}
```

The default action allows every system call. The one rule makes the kernel return error number 1 (`EPERM`, shown as `Operation not permitted`) for the calls that create a directory or a device file.

## Install The Profile

Create the `profiles` folder in the kubelet seccomp directory and copy the file into it. The value of `localhostProfile` is the path relative to `/var/lib/kubelet/seccomp`, so this file becomes `profiles/scout-guard.json`:

```sh
podman exec "$node_name" mkdir -p /var/lib/kubelet/seccomp/profiles
podman exec "$node_name" cp /opt/course/seccomp/scout-guard.json /var/lib/kubelet/seccomp/profiles/scout-guard.json
podman exec "$node_name" ls -l /var/lib/kubelet/seccomp/profiles
```

```text
total 4
-rw-r--r--. 1 root root 184 Nov 17 21:46 scout-guard.json
```

This cluster has one node. In a cluster with several nodes, you repeat the copy on every node where the pod can run.

## Create The Pod

Save this as `pod-scout.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: scout
  namespace: starfleet-033-040-01-01
spec:
  restartPolicy: Never
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/scout-guard.json
  containers:
  - name: scout
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
```

Apply it:

```sh
kubectl apply -f pod-scout.yaml
```

```text
pod/scout created
```

Then wait until the pod is ready:

```sh
kubectl -n starfleet-033-040-01-01 wait --for=condition=Ready pod/scout --timeout=180s
```

```text
pod/scout condition met
```

## Verify The Result

The `Seccomp:` line in `/proc/1/status` shows the seccomp mode of the main process. The value `2` means the container runtime installed a filter:

```sh
kubectl -n starfleet-033-040-01-01 exec scout -- grep Seccomp /proc/1/status
```

```text
Seccomp:	2
Seccomp_filters:	1
```

A file write uses other system calls, so it still works:

```sh
kubectl -n starfleet-033-040-01-01 exec scout -- sh -c 'echo cargo > /tmp/manifest && cat /tmp/manifest'
```

```text
cargo
```

The next command is expected to fail, so run it on its own:

```sh
kubectl -n starfleet-033-040-01-01 exec scout -- mkdir /tmp/samples
```

```text
mkdir: can't create directory '/tmp/samples': Operation not permitted
command terminated with exit code 1
```

The user in the container is root and `/tmp` is writable, so file permissions are not the cause. The kernel rejected the `mkdirat` system call because of the seccomp rule, and the pod keeps running.

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-01-01`.

## Common pitfalls

> [!WARNING]
> - Writing the full path `/var/lib/kubelet/seccomp/profiles/scout-guard.json` in `localhostProfile`. The value is relative to the kubelet seccomp directory.
> - Creating the pod before the file is in place. The container then fails with `CreateContainerError`. The kubelet retries, so the pod starts once the file exists, but until then the events show `cannot load seccomp profile`.
> - Copying the profile to one node of several. The pod fails on every node that lacks the file.
