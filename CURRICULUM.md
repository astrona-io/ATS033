# Curriculum Coverage

Exam: Certified Kubernetes Security Specialist (CKS). Domain: System Hardening (10%).

The [official objectives](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/) were checked on 2026-10-11. Teaching structure is independently authored and does not add official requirements.

| Section | Official objective | Modules |
| --- | --- | --- |
| 010 | Minimize host OS footprint (reduce attack surface) | 1 |
| 020 | Using least-privilege identity and access management | 1 |
| 030 | Minimize external access to the network | 1 |
| 040 | Appropriately use kernel hardening tools such as AppArmor, seccomp | 1 |

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Reducing The Host Operating-System Attack Surface | Reducing The Host Operating-System Attack Surface |
| 020 / 01 | Least Privilege For Host Identities And Administration | Least Privilege For Host Identities And Administration |
| 030 / 01 | Minimizing External Access To Host Services | Minimizing External Access To Host Services |
| 040 / 01 | Seccomp And AppArmor As Different Kernel Boundaries | Seccomp And AppArmor As Different Kernel Boundaries |

AUTHORING.yaml records measurable goals and adaptation sources. Every objective retains its section ID. All technical readings remain draft. Question banks are separate from the reading manifest and follow their declared summaries. Each module has a private playground, and graded labs follow the readings they practise.

## Hands-On Coverage

This course has 12 ungraded module playgrounds and 36 graded labs. Each lab is registered right after the reading it practises. 20 labs and 7 playgrounds run on a kind cluster. 16 labs and 5 playgrounds that work on node files, services, packages, sshd, ufw, static Pods, the kubelet, etcd or AppArmor run in a one-node kubeadm virtual machine (QEMU) built from the pinned `ubuntu-qcow2-image:24.04-cks-20261118` image. 36 labs passed `astrona validate` and `astrona test` on their live runtime.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Close An Unneeded Listener On A Node; Purge An Unneeded Package From A Node |
| 010/02 | Restrict SSH Logins In sshd_config; Close Unused And Duplicate Root Accounts |
| 010/03 | Remove Host Access From A Workload; Enforce The Baseline Pod Security Standard; Dedicate A Worker Node To One Workload |
| 020/01 | Grant Read Access Through A Group; Lock And Expire A Departed Account; Revoke A Leaver's Access Everywhere |
| 020/02 | Scope Access With resourceNames And A RoleBinding; Replace Wildcard And Cluster-Admin Access; Find Hidden RBAC Grants |
| 020/03 | Give A Workload Its Own ServiceAccount; Mount A Short-Lived Projected Token; Close The Default ServiceAccount |
| 030/01 | Bind A Host-Network Service To Loopback; Block A Host Port With ufw; Default-Deny Ingress With One Allowed Client |
| 030/02 | Close An Accidental NodePort; Answer A NodePort Only On Nodes With Endpoints; Audit And Close Unapproved Service Exposure |
| 030/03 | Bind The Scheduler To Loopback; Remove Anonymous Access From RBAC Bindings; Close The Kubelet API To Anonymous Callers; Restrict The etcd Data Directory |
| 040/01 | Install And Use A Localhost seccomp Profile; Load An AppArmor Profile And Attach It To A Pod; Harden A Deployment To The Restricted Pod Security Level; Fix A Pod That References A Missing seccomp Profile |
| 040/02 | Apply The RuntimeDefault seccomp Profile To Deployments; Block File Deletion With A Localhost seccomp Profile; Find And Fix A Blocked System Call In A seccomp Profile |
| 040/03 | Switch An AppArmor Profile From Complain To Enforce Mode; Set An AppArmor Profile For One Container; Drop All Capabilities Except NET_BIND_SERVICE |
