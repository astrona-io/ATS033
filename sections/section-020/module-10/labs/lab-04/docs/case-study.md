---
exam_objectives:
- Using least-privilege identity and access management
---
# Starting Environment

The cluster runs in one virtual machine, and that machine is its only node. The Linux audit daemon (`auditd`) runs with the default Ubuntu settings in `/etc/audit/rules.d/audit.rules`. One more rule file, `/etc/audit/rules.d/30-sudoers-main.rules`, holds the watch rule `-w /etc/sudoers -p wa -k sudoers-main`, and that rule is loaded in the kernel.

The account `oncall` exists and has no sudo rule. No rule watches the directory `/etc/sudoers.d`, so a new file there leaves no record in `/var/log/audit/audit.log`. The task is to add a persistent watch rule, load it, and then add the sudo rule for `oncall`.
