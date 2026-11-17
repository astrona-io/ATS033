---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Switch An AppArmor Profile From Complain To Enforce Mode Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-03-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

This walkthrough has no command output. The lab needs a host kernel with AppArmor, and it has not yet run on such a host. Each step says what a correct result contains, so you can compare your own output with it.

## Find The Current Mode

The kernel keeps one list of loaded profiles per node, in `/sys/kernel/security/apparmor/profiles`. Each line holds a profile name and its mode in parentheses. Read the line for `k8s-deny-etc-write` on both nodes:

```sh
for node_name in astro-ats-033-lab-040-03-01-control-plane astro-ats-033-lab-040-03-01-worker; do
  podman exec "$node_name" grep k8s-deny-etc-write /sys/kernel/security/apparmor/profiles
done
```

Each node prints `k8s-deny-etc-write (complain)`. In complain mode the kernel allows an operation that the profile does not allow, and only writes an audit message. The same is visible from inside the pod. `/proc/1/attr/current` shows the profile of the main process, and here it reads `k8s-deny-etc-write (complain)`:

```sh
kubectl -n starfleet-033-040-03-01 exec deploy/scout -- cat /proc/1/attr/current
```

So a write under `/etc` still works now, although no rule allows it:

```sh
kubectl -n starfleet-033-040-03-01 exec deploy/scout -- touch /etc/scout-check
```

The command prints nothing and returns exit code 0.

## Load The Profile In Enforce Mode

The mode is a property of the loaded profile, not of the file. `apparmor_parser -r` replaces the loaded profile with the content of the file. With `-C` it loads in complain mode, and without `-C` in enforce mode. Load the same file again without `-C` on both nodes:

```sh
for node_name in astro-ats-033-lab-040-03-01-control-plane astro-ats-033-lab-040-03-01-worker; do
  podman exec "$node_name" apparmor_parser -r /etc/apparmor.d/k8s-deny-etc-write
done
```

The command prints nothing when it works. Read the list again. Each node now prints `k8s-deny-etc-write (enforce)`:

```sh
for node_name in astro-ats-033-lab-040-03-01-control-plane astro-ats-033-lab-040-03-01-worker; do
  podman exec "$node_name" grep k8s-deny-etc-write /sys/kernel/security/apparmor/profiles
done
```

## Restart The Workload

The kernel applies a replaced profile to processes that already run under it. A restart still gives a clean result: the new pod starts under the profile as it is loaded now, and it shows that the container can start in enforce mode. Restart the Deployment and wait for the rollout:

```sh
kubectl -n starfleet-033-040-03-01 rollout restart deployment/scout
kubectl -n starfleet-033-040-03-01 rollout status deployment/scout --timeout=180s
```

A correct result ends with the line `deployment "scout" successfully rolled out`.

## Verify The Result

`kubectl exec deploy/scout` picks a pod that is not being deleted. The main process now reads `k8s-deny-etc-write (enforce)`:

```sh
kubectl -n starfleet-033-040-03-01 exec deploy/scout -- cat /proc/1/attr/current
```

The last check must fail. A correct result is a `Permission denied` message from `touch` and a non-zero exit code:

```sh
kubectl -n starfleet-033-040-03-01 exec deploy/scout -- touch /etc/scout-check
```

The container runs as root, so file permissions allow the write. Only the AppArmor profile stops it.

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-03-01`.

## Common pitfalls

> [!WARNING]
> - Switching only one node. The pod may run on the other node, where the profile is still in complain mode.
> - Running `aa-enforce` when the tool is missing in the node. `apparmor_parser -r` without `-C` does the same and needs only the parser.
> - Checking the mode only in the manifest. The Deployment names the profile, but the mode lives in the kernel of each node.
