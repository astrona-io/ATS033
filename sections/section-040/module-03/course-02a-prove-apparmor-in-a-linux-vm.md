---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Prove AppArmor Enforcement In A Linux VM

A denied file write proves little until you know which control rejected it. Ordinary file permissions, a read-only filesystem and AppArmor can all reject the same command. Compare a confined process with an unconfined process using the same identity and path.

## Why this exercise uses a VM

The independent AppArmor lab boots Ubuntu in QEMU. Its kernel has AppArmor enabled, regardless of the security module used by your container engine. The supplied tools include `apparmor_parser`, which loads profiles, and `aa-exec`, which starts a process under a named profile. The Kubernetes capability exercise uses kind because its controls do not require loading an AppArmor profile into your host kernel.

Run the examples below inside the AppArmor lab VM after connecting with `astrona ssh ats-033-lab-040-03-02`. They use a preview profile; the task asks you to create a separate profile. The VM starts with two directories, `/srv/allowed` and `/srv/protected`, both writable through ordinary file permissions.

## Load and identify the profile

Save the following as `/etc/apparmor.d/training-preview` using `sudo tee`:

```text
#include <tunables/global>
profile training-preview {
  #include <abstractions/base>
  file,
  network,
  capability,
  deny /srv/protected/** w,
}
```

The broad `file,` rule permits file operations; the explicit deny overrides it for writes below one directory. This is a demonstration of enforcement, not a production allow list. Load it and ask a new process which profile applies:

```sh
sudo apparmor_parser -r /etc/apparmor.d/training-preview
sudo aa-exec -p training-preview -- cat /proc/self/attr/current
```

Look for `training-preview (enforce)`. A profile present on disk has no effect until loaded. A loaded profile has no effect on a process that does not select it.

## Compare the same access with and without confinement

Create a fresh filename so an existing file cannot hide the result:

```sh
proof="proof-$(date +%s)"
sudo sh -c 'echo baseline > "$1"' sh "/srv/protected/$proof"
sudo rm "/srv/protected/$proof"
sudo aa-exec -p training-preview -- sh -c 'echo allowed > "$1"' sh "/srv/allowed/$proof"
sudo aa-exec -p training-preview -- cat /srv/protected/reference
sudo aa-exec -p training-preview -- sh -c 'echo denied > "$1"' sh "/srv/protected/$proof"
```

Run the last command separately if your shell exits on errors. It should fail with `Permission denied`, while the other access succeeds. The unconfined write establishes that ordinary permissions allow access. The active profile and the denied confined write establish the AppArmor boundary.

## Complain mode has an exception

Complain mode permits and logs access that is missing from an allow list. An explicit `deny` rule still denies access in complain mode, and an unqualified explicit deny can suppress the corresponding audit message. Therefore, a denied write alone does not establish enforce mode. Inspect the profile mode as well as its behavior. Do not interpret an empty kernel log as permission to access the path.

An administrator with authority to replace or remove the profile can change this boundary. The exercise assesses a confined process, not protection against a hostile VM administrator. When the preview is no longer needed, remove its loaded profile:

```sh
sudo apparmor_parser -R /etc/apparmor.d/training-preview
```
