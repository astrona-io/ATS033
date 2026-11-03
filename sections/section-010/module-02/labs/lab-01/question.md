---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Harden SSH Access And Unused Accounts

Make key-only SSH access for one administrator account on a node and remove login paths of an unused account.

## Starting state

The control-plane node of this environment holds a stand-in SSH server configuration in `/etc/ssh/sshd_config`, a drop-in file `/etc/ssh/sshd_config.d/50-cloud-init.conf`, and two accounts: `opsadmin`, the account that administrators use, and `olduser`, an account nobody uses any more. The setup script writes the files itself, so the exercise does not depend on an SSH server being installed in the node image. Today root may log in over SSH, the first `PasswordAuthentication` value that the daemon reads allows passwords, any account may log in, and `olduser` has the shell `/bin/bash`.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-02-01" || exit 1
node_name="astro-ats-033-lab-010-02-01-control-plane"
worker_name="astro-ats-033-lab-010-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Change only the control-plane node of this environment.

1. Set `PermitRootLogin` to `no`.
2. Make the first `PasswordAuthentication` value that sshd reads `no`. Keep `PubkeyAuthentication` set to `yes`.
3. Allow only the account `opsadmin` with an `AllowUsers` line.
4. Give `olduser` the login shell `/usr/sbin/nologin` and lock its password. Do not delete the account and do not change `opsadmin`.
5. Create the ConfigMap `node-access-review` in the `starfleet` namespace with the data `ssh: key-only`, `account: olduser` and `result: hardened`.

The `kubelet` and `containerd` services must stay active and the API readiness endpoint must answer.

## Verify The Result

The grader reads the effective SSH settings the way the daemon does, checks both accounts and checks the ConfigMap. Preserve the workloads of the `starfleet` and `outpost` namespaces and every other component.
