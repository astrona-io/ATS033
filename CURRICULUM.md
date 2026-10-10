# Curriculum And Authoring Plan

Exam: Certified Kubernetes Security Specialist (CKS). Domain: System Hardening (10%).
Source: [official curriculum](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/), checked 2026-10-10.
Objectives are attributed to The Linux Foundation and CNCF.

Preparation scaffold; content authoring has not started.

| Section | Official objective | Authoring status |
| --- | --- | --- |
| 010 | Minimize host OS footprint (reduce attack surface) | Planned |
| 020 | Using least-privilege identity and access management | Planned |
| 030 | Minimize external access to the network | Planned |
| 040 | Appropriately use kernel hardening tools such as AppArmor, seccomp | Planned |

Before building content:

- Recheck the curriculum and refine broad objectives into teachable modules.
- Choose and record the environment versions and any image dependencies.
- Write the introduction and remove placeholder notices only when it is ready.
- Build short parts and runnable playgrounds; add graded labs where appropriate.
- Add quizzes and a capstone when the completed domain needs them.
- Check real outputs and reference solutions, and update `astrona.yaml`.
- Remove `draft: true` from completed technical pages after review.
- Publish the course only after the maintainer approves the completed content.
