---
exam_objectives:
- Using least-privilege identity and access management
---
# Grant Read Access Through A Group Solution

Select the private cluster and define a small helper. The helper `run_on_node` runs one command inside the control-plane node container, so every command below changes only this lab's node.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-01-01" || exit 1
node_name="astro-ats-033-lab-020-01-01-control-plane"
run_on_node() { podman exec "$node_name" "$@"; }
```

## 1. Inspect the file, the accounts and the group

Start by reading the current state. `ls -l` shows the owner, the group and the permission bits. `id` shows the groups of each account, and `getent group` shows the members of the group.

```sh
run_on_node ls -l /srv/flight-logs
run_on_node id navigator
run_on_node id cadet
run_on_node getent group flight-log-readers
```

```text
total 4
-rw-r--r--. 1 root root 21 Nov 17 21:46 telemetry.log
uid=1000(navigator) gid=1001(navigator) groups=1001(navigator)
uid=1001(cadet) gid=1002(cadet) groups=1002(cadet)
flight-log-readers:x:1000:
```

The mode `-rw-r--r--` gives read access to the owner, the group and all other accounts. The group `flight-log-readers` exists but has no members yet. Test the problem as the account, not as `root`, because `root` can read every file. `runuser -u <user> -- <command>` runs one command as that user:

```sh
run_on_node runuser -u cadet -- cat /srv/flight-logs/telemetry.log
```

```text
orbit=stable fuel=82
```

The read as `cadet` succeeds, so the file is open to every account on the node.

## 2. Give the file to the group and close it for other accounts

`chgrp` sets the group of the file, and `chmod 0640` sets read and write for the owner, read for the group and nothing for other accounts. The owner stays `root`.

```sh
run_on_node chgrp flight-log-readers /srv/flight-logs/telemetry.log
run_on_node chmod 0640 /srv/flight-logs/telemetry.log
run_on_node ls -l /srv/flight-logs/telemetry.log
```

```text
-rw-r-----. 1 root flight-log-readers 21 Nov 17 21:46 /srv/flight-logs/telemetry.log
```

Now test both accounts again:

```sh
run_on_node runuser -u cadet -- cat /srv/flight-logs/telemetry.log
run_on_node runuser -u navigator -- cat /srv/flight-logs/telemetry.log
```

```text
cat: /srv/flight-logs/telemetry.log: Permission denied
cat: /srv/flight-logs/telemetry.log: Permission denied
```

Both reads fail. The kernel checks the "other" bits for both accounts, because neither of them is the owner or a member of the file's group.

## 3. Add navigator to the group

`usermod --append --groups` adds one supplementary group and keeps the existing ones. Without `--append`, `usermod --groups` replaces the whole list.

```sh
run_on_node usermod --append --groups flight-log-readers navigator
run_on_node id navigator
run_on_node getent group flight-log-readers
```

```text
uid=1000(navigator) gid=1001(navigator) groups=1001(navigator),1000(flight-log-readers)
flight-log-readers:x:1000:navigator
```

The account now lists `flight-log-readers`, and the group lists `navigator` as a member.

## 4. Verify the result as each account

`runuser` starts a new process, and a new process reads the current group list. Read the file as both accounts:

```sh
run_on_node runuser -u navigator -- cat /srv/flight-logs/telemetry.log
run_on_node runuser -u cadet -- cat /srv/flight-logs/telemetry.log
```

```text
orbit=stable fuel=82
cat: /srv/flight-logs/telemetry.log: Permission denied
```

`navigator` reads the log through the group bits, and `cadet` is still denied. Submit with `astrona submit`. When you are done, remove the lab with `astrona destroy ats-033-lab-020-01-01`.

## Common pitfalls

> [!WARNING]
> - **Testing as root.** A read as `root` always succeeds and proves nothing. Use `runuser -u <user>`.
> - **Forgetting `--append`.** `usermod --groups` without `--append` removes every other supplementary group of the account.
> - **Changing only one side.** Adding `navigator` to the group does not close the file for `cadet`. Remove the read bit for other accounts too.
> - **Expecting an open session to see the new group.** A process that is already running keeps its old groups. A new login or a new `runuser` process sees the change.
