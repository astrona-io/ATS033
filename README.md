<p align="center">
  <a href="https://astrona.io/courses/certified-kubernetes-security-specialist">
    <img src="https://astrona.io/courses/certified-kubernetes-security-specialist/domains/ATS033.svg" alt="ATS033: System Hardening, part of the Certified Kubernetes Security Specialist course on Astrona" width="100%">
  </a>
</p>

# Certified Kubernetes Security Specialist (CKS) - System Hardening (ATS033)

Learn to harden the nodes a Kubernetes cluster runs on, and to limit what a workload can do to its host. This course covers the System Hardening domain of the Certified Kubernetes Security Specialist (CKS) exam, which is 10% of the score.

You read how each control works, try it in your own playground, and then prove it in a graded lab. Take the course on [Astrona](https://astrona.io/courses/certified-kubernetes-security-specialist).

## What you will learn

**The host operating system.** Remove services and packages a node does not need, lock down SSH and host logins, and keep workloads away from the host.

- Reduce The Host Operating-System Attack Surface
- Harden Node Access With SSH And Host Login Paths
- Restrict Workload Access To The Host

**Least-privilege identities.** Give users, groups, RBAC subjects and ServiceAccounts only the access they need, and take it away again.

- Apply Least Privilege To Identities
- Least-Privilege RBAC Roles And Bindings
- Restrict ServiceAccounts And API Tokens

**External network access.** Close listeners and ports, limit how Services are exposed, and protect the API server and control-plane ports.

- Minimize External Access To The Network
- Limit Service Exposure Outside The Cluster
- Restrict Access To The API Server And Control-Plane Ports

**Kernel hardening.** Filter system calls with seccomp, confine files and capabilities with AppArmor, and fix the profiles that break a Pod.

- Kernel Hardening With seccomp And AppArmor
- Apply seccomp Profiles To Pods
- Confine Workloads With AppArmor And Capabilities

## How the course works

- **Reading pages** explain one idea at a time, with real commands and output.
- **Playgrounds** are private, ungraded environments for following along. Some run on kind (Kubernetes in Docker); the modules that work on node files, services, packages, SSH, the firewall, the kubelet, etcd or AppArmor use a QEMU virtual machine with a kubeadm cluster.
- **Labs** give you an exam-style task in a fresh environment and grade the result.
- **Knowledge checks** close each module with a short quiz.

You start playgrounds and labs with the `astrona` CLI, and work in a browser workspace with a terminal ready to use.

## Contributing

Found a mistake or want to improve something? See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Created by Astrona.io. Course content is licensed under [CC BY-NC-SA 4.0](LICENSE-CONTENT), and code under [AGPL v3](LICENSE). See [NOTICE](NOTICE) for details.
