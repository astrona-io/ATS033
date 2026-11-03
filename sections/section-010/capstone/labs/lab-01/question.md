---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Harden A Node And Its Workloads

A node and its workloads share one cluster, and four separate faults weaken it: a service nobody needs, weak SSH settings, a workload with host access and a sensitive workload without a dedicated node.

## Starting state

The cluster has one control-plane node and one worker node. Each node is a Podman container that runs systemd. The `starfleet` namespace runs the `probe` application, the `beacon` Deployment and the `ledger` Deployment. The `outpost` namespace runs the `drifter` pod.

Four faults exist. The control-plane node runs `training-extra.service`, which is enabled and has no job. The worker node holds a stand-in SSH server configuration in `/etc/ssh/sshd_config` and `/etc/ssh/sshd_config.d/50-cloud-init.conf` that allows root and password logins and allows any account, and it has an unused account `olduser` with the shell `/bin/bash` next to the administrator account `opsadmin`. The `beacon` pod template uses `hostNetwork`, `hostPID`, a privileged container and a `hostPath` volume of `/var/log`. The `ledger` Deployment handles sensitive data but runs wherever the scheduler places it, and the worker node has no label or taint for it.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-010-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-010-capstone-01" || exit 1
node_name="astro-ats-033-lab-010-capstone-01-control-plane"
worker_name="astro-ats-033-lab-010-capstone-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Repair all four faults. Change only the objects and node settings named here.

1. On the control-plane node, stop and disable `training-extra.service`.
2. On the worker node, make the effective SSH settings `PermitRootLogin no`, `PasswordAuthentication no` (the first value that sshd reads), `PubkeyAuthentication yes` and `AllowUsers opsadmin`. Give `olduser` the shell `/usr/sbin/nologin` and lock its password. Keep `opsadmin` unchanged.
3. Rewrite the `beacon` pod template: no host namespaces, an `emptyDir` volume named `scratch` mounted at `/scratch` instead of the `hostPath` volume, and a container with `privileged: false`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `runAsNonRoot: true`, `runAsUser: 10001` and all capabilities dropped. Label the `starfleet` namespace `pod-security.kubernetes.io/enforce=baseline`.
4. Dedicate the worker node to `ledger`. Label the node `node-restriction.kubernetes.io/dedicated=ledger` and taint it `dedicated=ledger:NoSchedule`. Give the `ledger` pod template the matching `nodeSelector` and a toleration for the taint. The `ledger` pod must run on the worker node.
5. Create the ConfigMap `section-review` in the `starfleet` namespace with the data `node-service: disabled`, `ssh: key-only`, `workload: beacon` and `dedicated-node: ledger`.

The `kubelet` and `containerd` services must stay active on both nodes, the API readiness endpoint must answer, and the `probe` Deployment must keep two ready replicas. Order matters: a taint with the effect `NoSchedule` keeps new pods away from the node, so finish every rollout that needs a pod on the worker node before you add the taint.

## Verify The Result

The grader reads the services and files on both nodes, the pod templates, the running pods, the node label and taint, the namespace label and the ConfigMap. Wait for every rollout to finish before you submit. Preserve every unrelated component.
