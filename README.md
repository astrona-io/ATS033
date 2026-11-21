<p align="center">
  <a href="https://astrona.io/courses/certified-kubernetes-security-specialist">
    <img src="https://astrona.io/courses/certified-kubernetes-security-specialist/domains/ATS033.svg" alt="ATS033: System Hardening, part of the Certified Kubernetes Security Specialist course on Astrona" width="100%">
  </a>
</p>

# System Hardening (ATS033)

Certified Kubernetes Security Specialist (CKS): System Hardening, worth 10% of the official curriculum. This course belongs to ATP007.

Developed reading explains mechanisms, responsible components, examples and limits. Every section has an introduction and every module closes with a summary. Reusable YAML checks contain 5–15 questions per bank. Private playgrounds and graded labs are included.

## Course Outline

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Reduce The Host Operating-System Attack Surface | Inventory Services And Listeners; Stop, Disable And Mask Services; Remove Packages And Keep The Node Working; Privileged Host Interfaces |
| 020 / 01 | Apply Least Privilege To Identities | Users, Groups And File Permissions; Privilege Elevation And Account Locking; Kubernetes Identities And RBAC; Revoking Host And Kubernetes Access; Audit Trails On The Node And In The Cluster; Persistent Audit Rules With augenrules |
| 030 / 01 | Minimize External Access To The Network | Listeners And Bind Addresses; Host Firewalls With iptables And ufw; NetworkPolicy For Pod Traffic; NodePorts, Control-Plane Ports And API Access |
| 040 / 01 | Kernel Hardening With seccomp And AppArmor | Seccomp: Filtering System Calls; AppArmor: Profiles For Files And Capabilities; The Restricted Security Context; Diagnosing Profile Failures |

## Author Review

See [curriculum coverage](CURRICULUM.md), [primary sources](SOURCES.md), [question-bank documentation](ASSESSMENTS.md) and [contribution instructions](CONTRIBUTING.md). Live lab results are recorded per lab in AUTHORING.yaml.

## Hands-On Coverage

This course has 12 ungraded module playgrounds and 37 graded labs. Each lab is registered right after the reading it practises. 20 labs and 7 playgrounds run on a kind cluster. 17 labs and 5 playgrounds that work on node files, services, packages, sshd, ufw, static Pods, the kubelet, etcd or AppArmor run in a one-node kubeadm virtual machine (QEMU) built from the multi-arch `ubuntu-qcow2-image:24.04-cks` image (astrona picks the image for the CPU architecture of the computer and checks it against a pinned checksum). 37 labs passed `astrona validate` and `astrona test` on their live runtime.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Close An Unneeded Listener On A Node; Purge An Unneeded Package From A Node |
| 010/02 | Restrict SSH Logins In sshd_config; Close Unused And Duplicate Root Accounts |
| 010/03 | Remove Host Access From A Workload; Enforce The Baseline Pod Security Standard; Dedicate A Worker Node To One Workload |
| 020/01 | Grant Read Access Through A Group; Lock And Expire A Departed Account; Revoke A Leaver's Access Everywhere; Record Every Change To The Sudo Rules |
| 020/02 | Scope Access With resourceNames And A RoleBinding; Replace Wildcard And Cluster-Admin Access; Find Hidden RBAC Grants |
| 020/03 | Give A Workload Its Own ServiceAccount; Mount A Short-Lived Projected Token; Close The Default ServiceAccount |
| 030/01 | Bind A Host-Network Service To Loopback; Block A Host Port With ufw; Default-Deny Ingress With One Allowed Client |
| 030/02 | Close An Accidental NodePort; Answer A NodePort Only On Nodes With Endpoints; Audit And Close Unapproved Service Exposure |
| 030/03 | Bind The Scheduler To Loopback; Remove Anonymous Access From RBAC Bindings; Close The Kubelet API To Anonymous Callers; Restrict The etcd Data Directory |
| 040/01 | Install And Use A Localhost seccomp Profile; Load An AppArmor Profile And Attach It To A Pod; Harden A Deployment To The Restricted Pod Security Level; Fix A Pod That References A Missing seccomp Profile |
| 040/02 | Apply The RuntimeDefault seccomp Profile To Deployments; Block File Deletion With A Localhost seccomp Profile; Find And Fix A Blocked System Call In A seccomp Profile |
| 040/03 | Switch An AppArmor Profile From Complain To Enforce Mode; Set An AppArmor Profile For One Container; Drop All Capabilities Except NET_BIND_SERVICE |
