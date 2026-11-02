# System Hardening (ATS033)

Certified Kubernetes Security Specialist (CKS): System Hardening, worth 10% of the official curriculum. This course belongs to ATP007.

Developed reading explains mechanisms, responsible components, examples and limits. Every section has an introduction and every module closes with a summary. Reusable YAML checks contain 5–15 questions per bank. Technical content remains draft. Private playgrounds and draft graded labs are included.

## Course Outline

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Reduce The Host Operating-System Attack Surface | Inventory Services And Listeners; Stop, Disable And Mask Services; Remove Packages And Keep The Node Working; Privileged Host Interfaces |
| 020 / 01 | Apply Least Privilege To Identities | Users, Groups And File Permissions; Privilege Elevation And Account Locking; Kubernetes Identities And RBAC; Revocation And Audit |
| 030 / 01 | Minimize External Access To The Network | Listeners And Bind Addresses; Host Firewalls With iptables And ufw; NetworkPolicy For Pod Traffic; NodePorts, Control-Plane Ports And API Access |
| 040 / 01 | Kernel Hardening With seccomp And AppArmor | Seccomp: Filtering System Calls; AppArmor: Profiles For Files And Capabilities; The Restricted Security Context; Diagnosing Profile Failures |

## Author Review

See [curriculum coverage](CURRICULUM.md), [primary sources](SOURCES.md), [question-bank documentation](ASSESSMENTS.md) and [contribution instructions](CONTRIBUTING.md). No runtime execution is claimed.

## Hands-On Coverage

This course has 4 ungraded module playgrounds and 4 draft independent labs. Tasks and solutions are registered around each lab immediately after its teaching reading. Static configuration, shell/Python/YAML, parser, lifecycle and offline grader checks pass. Live execution remains pending because the session cannot access Podman; installed CLI configuration validation is separately blocked by its maintenance lock.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Disable An Unneeded Node Service |
| 020/01 | Grant One Host Identity Scoped Read Access |
| 030/01 | Bind A Host-Network Service To Loopback |
| 040/01 | Run With A Restricted Security Context |
