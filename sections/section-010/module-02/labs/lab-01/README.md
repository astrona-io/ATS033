---
draft: true
---
# Harden A Running SSH Service

Use the independent QEMU VM to reload a separate sshd listener on port 2222, preserve administrator key access and reject root, password and unused-account logins. The management listener on port 22 stays available.

`astrona test -c .` verifies the broken starting state, applies the reference solution, checks deliberately reopened authentication paths and runs the final graders.
