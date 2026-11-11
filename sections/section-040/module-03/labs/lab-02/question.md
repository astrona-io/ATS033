---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Enforce An AppArmor File Boundary

Solve this question on: `terminal`

This independent QEMU environment is an Ubuntu VM with AppArmor enabled. Both `/srv/allowed` and `/srv/protected` have mode `0777`; an unconfined process can write in either directory. The profile `training-write-boundary` does not exist. Run commands inside the VM:

```sh
astrona ssh ats-033-lab-040-03-02
```

Allow about 10 minutes for the tasks. First boot, image download and package installation add time.

## Tasks

1. Write `/etc/apparmor.d/training-write-boundary` with the profile name `training-write-boundary`. Permit reading `/srv/protected/reference` and writing below `/srv/allowed`, and deny writes below `/srv/protected`.
2. Load the profile in enforce mode. Use `aa-exec -p training-write-boundary -- ...` to start a process under it and inspect `/proc/self/attr/current`.
3. Prove the boundary with fresh files: the confined process can write in `/srv/allowed` and read the protected reference, but cannot write in `/srv/protected`. Confirm that an unconfined process can still write there.

## Constraints

- Keep AppArmor enabled and the profile in enforce mode.
- Keep both directories at mode `0777` and the reference file readable. A discretionary file permission failure does not prove AppArmor enforcement.
- Preserve the VM access accounts and `/opt/astrona-apparmor` test tools.

## How the answer is checked

The grader starts fresh processes under the loaded profile, checks their active profile, and compares allowed reads and writes with a denied write. It also repeats the unconfined write to rule out ordinary file permissions as the cause. This lab proves Linux AppArmor enforcement; the kind lab in this module assesses Kubernetes capabilities separately.
