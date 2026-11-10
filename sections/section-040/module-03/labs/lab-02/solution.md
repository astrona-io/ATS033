---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Solution

Connect to the lab VM, then save this as `/etc/apparmor.d/training-write-boundary` with `sudo tee`:

```text
#include <tunables/global>
profile training-write-boundary {
  #include <abstractions/base>
  file,
  network,
  capability,
  deny /srv/protected/** w,
}
```

This deliberately broad demonstration profile isolates one write restriction. It is not a production allow list.

```sh
sudo apparmor_parser -r /etc/apparmor.d/training-write-boundary
sudo aa-exec -p training-write-boundary -- cat /proc/self/attr/current
sudo aa-exec -p training-write-boundary -- sh -c 'echo allowed > /srv/allowed/proof'
sudo aa-exec -p training-write-boundary -- cat /srv/protected/reference
sudo aa-exec -p training-write-boundary -- sh -c 'echo denied > /srv/protected/proof'
```

The last command should report `Permission denied`. The profile identity must include `(enforce)`. Compare with an unconfined write:

```sh
sudo sh -c 'echo baseline > /srv/protected/proof'
sudo rm /srv/protected/proof
```

Run `astrona submit ats-033-lab-040-03-02` from your host terminal. Submission repeats the tests with new filenames.
