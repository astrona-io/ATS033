---
exam_objectives:
- Using least-privilege identity and access management
---
# Record Every Change To The Sudo Rules Solution

Open a shell on the lab VM. The VM is the only node of the cluster, so every command below runs on the node itself and changes only this lab.

```sh
astrona ssh astro-ats-033-lab-020-01-04
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-lab-020-01-04
```

You are logged in as `student`. This user may run any command as `root` through `sudo`, and its kubeconfig file gives `kubectl` administrator access to the cluster.

## 1. Look at the starting state

The Linux audit daemon (`auditd`) writes a record for every event that matches a rule in the kernel. `auditctl -l` lists the rules the kernel uses now. Persistent rules live in files under `/etc/audit/rules.d/`. Check both, and check that `oncall` has no sudo rule yet:

```sh
sudo auditctl -l
sudo ls /etc/audit/rules.d
sudo -l -U oncall
```

```text
-w /etc/sudoers -p wa -k sudoers-main
30-sudoers-main.rules
audit.rules
User oncall is not allowed to run sudo on astro-ats-033-lab-020-01-04.
```

The kernel watches `/etc/sudoers` only. A new file in `/etc/sudoers.d` would leave no record, so the watch must come first.

## 2. Write the persistent watch rule

A watch rule (`-w`) records access to one path. `-p wa` records writes and attribute changes, and `-k sudoers-change` adds a search key to each record. Write the rule to its own file, then ask `augenrules` whether the generated file `/etc/audit/audit.rules` is up to date:

```sh
echo '-w /etc/sudoers.d -p wa -k sudoers-change' | sudo tee /etc/audit/rules.d/40-sudoers.rules
sudo augenrules --check
```

```text
-w /etc/sudoers.d -p wa -k sudoers-change
/usr/sbin/augenrules: Rules have changed and should be updated
```

The file is on disk, but the kernel does not use it yet. Run `astrona submit` now if you like: the first check fails until the rules are loaded.

## 3. Load the rules without a reboot

`augenrules --load` joins every `.rules` file in `/etc/audit/rules.d/` into `/etc/audit/audit.rules` and loads that file into the kernel. Its output is a long status block, so hide it and list the rules instead:

```sh
sudo augenrules --load >/dev/null
sudo auditctl -l
sudo augenrules --check
```

```text
-w /etc/sudoers -p wa -k sudoers-main
-w /etc/sudoers.d -p wa -k sudoers-change
/usr/sbin/augenrules: No change
```

Both watches are active, and the generated file matches the rule files. The rule on `/etc/sudoers` is still there because `30-sudoers-main.rules` was not touched. Do not use `auditctl -D` here: it deletes all loaded rules, the guarded one too.

## 4. Add the sudo rule for oncall

Write the rule to a new file, set the owner and mode that sudo expects, and check the syntax of every sudoers file:

```sh
echo 'oncall ALL=(root) NOPASSWD: /usr/bin/journalctl --unit kubelet' | sudo tee /etc/sudoers.d/40-oncall
sudo chmod 0440 /etc/sudoers.d/40-oncall
sudo visudo -c
sudo -l -U oncall
```

```text
oncall ALL=(root) NOPASSWD: /usr/bin/journalctl --unit kubelet
/etc/sudoers: parsed OK
/etc/sudoers.d/40-oncall: parsed OK
/etc/sudoers.d/90-cloud-init-users: parsed OK
/etc/sudoers.d/README: parsed OK
Matching Defaults entries for oncall on astro-ats-033-lab-020-01-04:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin, use_pty

User oncall may run the following commands on astro-ats-033-lab-020-01-04:
    (root) NOPASSWD: /usr/bin/journalctl --unit kubelet
```

`tee` runs as root through `sudo`, so the new file belongs to `root:root`. sudo itself now lists the one command `oncall` may run.

## 5. Find the audit record

`ausearch` reads the audit log. `--input-logs` makes it read the log file, `-k` selects the key and `-f` selects the file. `--format text` prints each record as one sentence:

```sh
sudo ausearch --input-logs -k sudoers-change -f /etc/sudoers.d/40-oncall --format text
```

```text
At 10:57:47 11/18/26 student, acting as root, successfully opened-file /etc/sudoers.d/40-oncall using /usr/bin/tee
At 10:57:47 11/18/26 student, acting as root, successfully changed-file-permissions-of /etc/sudoers.d/40-oncall to 0440 using /usr/bin/chmod
```

Your times differ. The kernel recorded both the write and the mode change, and both records name `student`, the account that logged in. If you wrote the sudoers file before step 3, `ausearch` prints `<no matches>`. Remove the file and create it again now that the watch is active.

Submit with `astrona submit`. When you are done, leave the VM with `exit` and remove the lab with `astrona destroy ats-033-lab-020-01-04`.

## Common pitfalls

> [!WARNING]
> - **Adding the rule with `auditctl -w` only.** The kernel uses it, but `augenrules --check` reports a change, and the rule is gone after the next restart of `auditd`.
> - **Writing the sudoers file first.** The kernel cannot record a change that happened before the watch was loaded.
> - **Deleting all rules.** `auditctl -D` also removes the guarded watch on `/etc/sudoers`. Load the files again with `augenrules --load` if that happens.
> - **A rule file without the `.rules` ending.** `augenrules` ignores it.
> - **Breaking sudoers.** Run `visudo -c` after every change. A syntax error in any file under `/etc/sudoers.d` can stop sudo for everyone.
