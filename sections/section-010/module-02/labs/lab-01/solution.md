---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Restrict SSH Logins In sshd_config Solution

Select the private environment and define a helper. The helper `run_on_node` runs one command on the control-plane node container, which is the same as running it in a shell on the node.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-02-01" || exit 1
node_name="astro-ats-033-lab-010-02-01-control-plane"
worker_name="astro-ats-033-lab-010-02-01-worker"
run_on_node() { podman exec "$node_name" "$@"; }
```

## Read the settings in the order sshd reads them

The main file includes the drop-in directory on its second line, so `sshd` reads the drop-in files before the rest of the main file. The shell expands `*.conf` in alphabetical order, which is the order `sshd` uses. `grep -i` ignores upper and lower case, because `sshd` keywords do not depend on case, and `^ *` also catches indented lines inside a `Match` block:

```sh
run_on_node sh -c "grep -n -i -E '^ *(Include|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|AllowUsers|Match)' /etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config"
```

```text
/etc/ssh/sshd_config.d/10-legacy-root.conf:2:permitrootlogin yes
/etc/ssh/sshd_config.d/50-cloud-init.conf:1:PasswordAuthentication yes
/etc/ssh/sshd_config:2:Include /etc/ssh/sshd_config.d/*.conf
/etc/ssh/sshd_config:5:PermitRootLogin prohibit-password
/etc/ssh/sshd_config:6:PubkeyAuthentication yes
/etc/ssh/sshd_config:7:PasswordAuthentication no
/etc/ssh/sshd_config:12:Match User backup
```

The output shows three problems. The first `PermitRootLogin` value is `yes`, written in lower case in `10-legacy-root.conf`, so the `prohibit-password` line in the main file never applies. The first `PasswordAuthentication` value is `yes`, from `50-cloud-init.conf`. There is no `AllowUsers` line, so every account may log in. The main file also ends with a `Match` block:

```sh
run_on_node sed -n '10,16p' /etc/ssh/sshd_config
```

```text
Subsystem sftp internal-sftp

Match User backup
    # The backup account may only copy files.
    ForceCommand internal-sftp
    AllowTcpForwarding no
```

Every line after `Match User backup` belongs to that block, up to the end of the file. A line appended with `>>` would apply only to the `backup` account.

## Fix the values that sshd reads first

Change the lines that win, which are the lines in the drop-in files. The `I` flag at the end of the first `sed` expression makes the pattern ignore case, so it matches `permitrootlogin`:

```sh
run_on_node sed -i 's/^permitrootlogin .*/PermitRootLogin no/I' /etc/ssh/sshd_config.d/10-legacy-root.conf
run_on_node sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/50-cloud-init.conf
run_on_node sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
```

The commands print nothing when they succeed. The third command is optional: the main file value is read later and does not win, but making it say `no` as well keeps the files consistent for the next reader.

## Add a global AllowUsers line above the Match block

The `sed` command `i` inserts text before every line that matches the pattern. Here it inserts `AllowUsers opsadmin` and an empty line before `Match User backup`, so the new line stays global:

```sh
run_on_node sed -i '/^Match User backup/i AllowUsers opsadmin\n' /etc/ssh/sshd_config
```

A drop-in file such as `/etc/ssh/sshd_config.d/00-allow.conf` with the line `AllowUsers opsadmin` also works, because the `Include` line sits above the `Match` block.

## Verify the result

Read the settings again in the same order:

```sh
run_on_node sh -c "grep -n -i -E '^ *(Include|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|AllowUsers|Match)' /etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config"
run_on_node getent passwd opsadmin
```

```text
/etc/ssh/sshd_config.d/10-legacy-root.conf:2:PermitRootLogin no
/etc/ssh/sshd_config.d/50-cloud-init.conf:1:PasswordAuthentication no
/etc/ssh/sshd_config:2:Include /etc/ssh/sshd_config.d/*.conf
/etc/ssh/sshd_config:5:PermitRootLogin no
/etc/ssh/sshd_config:6:PubkeyAuthentication yes
/etc/ssh/sshd_config:7:PasswordAuthentication no
/etc/ssh/sshd_config:12:AllowUsers opsadmin
/etc/ssh/sshd_config:14:Match User backup
```

```text
opsadmin:x:1000:1000::/home/opsadmin:/bin/bash
```

The first value of each keyword is now the safe one, and `AllowUsers opsadmin` is on line 12, above the `Match` line on line 14. `opsadmin` keeps `/bin/bash`. On a node that runs `sshd`, you would now check the files with `sshd -t`, print the effective values with `sshd -T`, reload the daemon with `systemctl reload ssh` and test a new login from a second terminal before you close the first one. This node has no `sshd`, so the grader reads the files instead. Then submit.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-010-02-01`.

## Common pitfalls

> [!WARNING]
> - **Fixing only the main file.** The drop-in values are read first and win. Change the drop-in lines.
> - **Searching with case.** `grep PermitRootLogin` misses `permitrootlogin yes`. Use `grep -i`.
> - **Appending after a `Match` block.** `printf 'AllowUsers opsadmin\n' >> /etc/ssh/sshd_config` puts the line inside `Match User backup`, and the grader reports that `AllowUsers` appears only inside a `Match` block.
