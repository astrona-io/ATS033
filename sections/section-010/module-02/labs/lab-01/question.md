---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Question

Solve this question on: `terminal`

The control-plane node of this environment holds a stand-in SSH server configuration in `/etc/ssh/sshd_config`, a drop-in file `/etc/ssh/sshd_config.d/50-cloud-init.conf`, and two accounts: `opsadmin`, the account that administrators use, and `olduser`, an account nobody uses any more. The setup script writes the files itself, so the exercise does not depend on an SSH server being installed in the node image. Today root may log in over SSH, the first `PasswordAuthentication` value that the daemon reads allows passwords, any account may log in, and `olduser` has the shell `/bin/bash`.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-02-01" || exit 1
node_name="astro-ats-033-lab-010-02-01-control-plane"
worker_name="astro-ats-033-lab-010-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Refuse root logins: set `PermitRootLogin` to `no`.
2. Allow key logins for `opsadmin` only: make the first `PasswordAuthentication` value that sshd reads `no`, keep `PubkeyAuthentication` set to `yes`, and allow only `opsadmin` with an `AllowUsers` line.
3. Close the unused account: give `olduser` the login shell `/usr/sbin/nologin` and lock its password.
4. Record the change: create the ConfigMap `node-access-review` in the namespace `starfleet-033-010-02-01` with the data `ssh: key-only`, `account: olduser` and `result: hardened`.

## Constraints

- Change only the control-plane node of this environment.
- Do not delete `olduser`, and do not change `opsadmin`: it keeps the shell `/bin/bash`.
- The `kubelet` and `containerd` services must stay active, and the API readiness endpoint must answer.
- Preserve the workloads of the `starfleet-033-010-02-01` and `outpost-033-010-02-01` namespaces and every other component.

## How the answer is checked

The grader reads the effective SSH settings the way the daemon does: for each keyword, the first value in the drop-in files and then in `/etc/ssh/sshd_config` wins. It runs five checks: root logins are refused; password logins are refused while key logins stay on; `AllowUsers` allows only `opsadmin`; `olduser` has the `nologin` shell and a locked password; and the ConfigMap `node-access-review` has the required data. Every check also confirms `opsadmin`, `kubelet`, `containerd` and the API readiness endpoint.

Hint: sshd reads the drop-in directory before the rest of `/etc/ssh/sshd_config`, so a value in `50-cloud-init.conf` wins.
