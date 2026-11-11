# Curriculum Coverage

> Historical design record. Counts and execution claims below describe the original expansion. For current labs, preparation and practical limits, use [LAB-COVERAGE.md](LAB-COVERAGE.md) and [COVERAGE-REVIEW.md](COVERAGE-REVIEW.md).

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

AUTHORING.yaml records measurable goals and adaptation sources. Every objective retains its section ID. All technical readings remain draft. Question banks are separate from the reading manifest and follow their declared summaries. No labs, playgrounds or runtime validation are included.

## Hands-On Coverage

This course has 4 ungraded module playgrounds and 4 draft independent labs. Tasks and solutions are registered around each lab immediately after its teaching reading. Static configuration, shell/Python/YAML, parser, lifecycle and offline grader checks pass. Live execution remains pending because the session cannot access Podman; installed CLI configuration validation is separately blocked by its maintenance lock.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Disable An Unneeded Node Service |
| 020/01 | Grant One Host Identity Scoped Read Access |
| 030/01 | Bind A Host-Network Service To Loopback |
| 040/01 | Run With A Restricted Security Context |
