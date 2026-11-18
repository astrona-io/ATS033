---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Switch An AppArmor Profile From Complain To Enforce Mode Solution

The lab runs in a VM (virtual machine) with a one-node Kubernetes cluster built with kubeadm. Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-040-03-01
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-lab-040-03-01
```

You are logged in as the `student` user. The kernel profile list and the audit log belong to root, so the node commands below use `sudo`. The output on this page comes from a run on 2026-11-18.

## Find The Current Mode

The kernel keeps one list of loaded profiles, in `/sys/kernel/security/apparmor/profiles`. Each line holds a profile name and its mode in parentheses. Read the line for `k8s-deny-etc-write`:

```sh
sudo grep k8s-deny-etc-write /sys/kernel/security/apparmor/profiles
```

```text
k8s-deny-etc-write (complain)
```

The same is visible from inside the pod. `/proc/1/attr/current` shows the profile of the main process:

```sh
kubectl -n starfleet-033-040-03-01 exec deploy/scout -- cat /proc/1/attr/current
```

```text
k8s-deny-etc-write (complain)
```

In complain mode the kernel allows an access that no rule of the profile covers, and it writes an audit message. The profile has no rule for a write under `/etc`, so this write works now. The command prints nothing and returns exit code 0:

```sh
kubectl -n starfleet-033-040-03-01 exec deploy/scout -- touch /etc/scout-check
```

The VM runs `auditd`, so the kernel writes AppArmor messages to `/var/log/audit/audit.log`. Find the message for this write:

```sh
sudo grep 'profile="k8s-deny-etc-write"' /var/log/audit/audit.log | grep scout-check | tail -1
```

```text
type=AVC msg=audit(1794992705.891:815): apparmor="ALLOWED" operation="open" class="file" profile="k8s-deny-etc-write" name="/etc/scout-check" pid=2658 comm="touch" requested_mask="wc" denied_mask="wc" fsuid=0 ouid=0FSUID="root" OUID="root"
```

`apparmor="ALLOWED"` means the profile would deny this access, but complain mode let it through. In enforce mode the same line would say `apparmor="DENIED"`.

## Load The Profile In Enforce Mode

The mode is a property of the loaded profile, not of the file. `apparmor_parser -r` replaces the loaded profile with the content of the file. With `-C` it loads in complain mode, and without `-C` in enforce mode. Load the same file again without `-C`. The command prints nothing when it works:

```sh
sudo apparmor_parser -r /etc/apparmor.d/k8s-deny-etc-write
```

Then check the kernel list again:

```sh
sudo grep k8s-deny-etc-write /sys/kernel/security/apparmor/profiles
```

```text
k8s-deny-etc-write (enforce)
```

`sudo aa-enforce /etc/apparmor.d/k8s-deny-etc-write` does the same job, and it is also installed in the VM.

## Restart The Workload

The kernel applies a replaced profile to processes that already run under it. A restart still gives a clean result: the new pod starts under the profile as it is loaded now, and it shows that the container can start in enforce mode. Restart the Deployment and wait for the rollout:

```sh
kubectl -n starfleet-033-040-03-01 rollout restart deployment/scout
kubectl -n starfleet-033-040-03-01 rollout status deployment/scout --timeout=180s
```

```text
deployment.apps/scout restarted
Waiting for deployment "scout" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "scout" rollout to finish: 1 old replicas are pending termination...
deployment "scout" successfully rolled out
```

The old pod can stay in `Terminating` for up to 30 seconds, the default grace period, because the shell that runs as process 1 in the container ignores the `SIGTERM` signal. After the grace period the container runtime (`runc`) sends `SIGKILL`. The profile allows signals from `runc` with the rule `signal (receive) peer=runc,`, so the pod does end.

## Verify The Result

`kubectl exec deploy/scout` picks a pod that is not being deleted. The main process now runs in enforce mode:

```sh
kubectl -n starfleet-033-040-03-01 exec deploy/scout -- cat /proc/1/attr/current
```

```text
k8s-deny-etc-write (enforce)
```

The last check must fail. The container runs as root, so file permissions allow the write. Only the AppArmor profile stops it:

```sh
kubectl -n starfleet-033-040-03-01 exec deploy/scout -- touch /etc/scout-check
```

```text
touch: /etc/scout-check: Permission denied
command terminated with exit code 1
```

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-03-01`.

## Common pitfalls

> [!WARNING]
> - Forgetting `sudo`. As the `student` user, `apparmor_parser` and the read of the kernel profile list fail.
> - Loading the file again with `-C`. The profile stays in complain mode, and the write under `/etc` still works.
> - Looking for AppArmor messages with `dmesg` only. When `auditd` runs, the messages go to `/var/log/audit/audit.log`.
> - Checking the mode only in the manifest. The Deployment names the profile, but the mode lives in the kernel of the node.
