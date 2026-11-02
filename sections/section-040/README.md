---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Appropriately use kernel hardening tools such as AppArmor, seccomp

A process can open a permitted file but attempts a disallowed system call. File-access policy and syscall filtering constrain different behavior, even when both protect the same container.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Distinguish syscall filtering from resource-oriented mandatory access control.
- Interpret RuntimeDefault, Localhost and unconfined profile choices.
- Explain node prerequisites and container-level overrides.
- Diagnose profile failures while preserving the intended boundary.
