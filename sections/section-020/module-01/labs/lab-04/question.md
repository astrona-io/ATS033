---
exam_objectives:
- Using least-privilege identity and access management
---
# Question

Solve this question on: `terminal`

This lab runs a virtual machine (VM) with a one-node Kubernetes cluster, and the VM is the node. The account `oncall` needs a new sudo rule so that it can read the kubelet logs. Your team requires a record of every change to the sudo rules, so a change to `/etc/sudoers.d` must leave an entry in the audit log of the Linux audit daemon (`auditd`). Today, `auditd` watches only `/etc/sudoers`, through the rule file `/etc/audit/rules.d/30-sudoers-main.rules`. Nothing watches `/etc/sudoers.d` yet.

Open a shell on the lab VM and confirm the cluster:

```sh
astrona ssh astro-ats-033-lab-020-01-04
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-020-01-04`. You are logged in as the `student` user. Audit rules, audit logs and sudoers files belong to `root`, so run the commands that read or change them with `sudo`. They change only the lab VM, not your own computer.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Create the rule file `/etc/audit/rules.d/40-sudoers.rules` with a watch rule on the directory `/etc/sudoers.d`. The rule records writes and attribute changes (`-p wa`) and uses the key `sudoers-change`.
2. Load the rules from `/etc/audit/rules.d` into the kernel without a reboot, so that `auditctl -l` lists `-w /etc/sudoers.d -p wa -k sudoers-change`.
3. Create the file `/etc/sudoers.d/40-oncall`, owned by `root:root` with mode `0440`, with this one rule:

   ```text
   oncall ALL=(root) NOPASSWD: /usr/bin/journalctl --unit kubelet
   ```

4. Make sure the audit log has a record with the key `sudoers-change` for `/etc/sudoers.d/40-oncall`.

## Constraints

- Keep `/etc/audit/rules.d/30-sudoers-main.rules` and its loaded rule `-w /etc/sudoers -p wa -k sudoers-main`.
- Do not stop or turn off `auditd`, and do not delete all rules with `auditctl -D`.
- All sudoers files must pass `visudo -c`.

## How the answer is checked

The grader runs four checks. The first check reads `/etc/audit/rules.d/40-sudoers.rules` and runs `augenrules --check`, which must report no change. The second check expects `auditctl -l` to list the watch on `/etc/sudoers.d`. The third check confirms the owner and mode of `/etc/sudoers.d/40-oncall`, runs `visudo -c` and expects `sudo -l -U oncall` to list the `journalctl` command. The fourth check runs `ausearch --input-logs -k sudoers-change -f /etc/sudoers.d/40-oncall`, which must find a record. Every check also confirms that the rule file `30-sudoers-main.rules` and its loaded rule are still there.
