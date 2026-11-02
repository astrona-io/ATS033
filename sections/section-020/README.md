---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Using least-privilege identity and access management

An automation account can restart a service but also has unrestricted host administrator access. Its required action does not justify every operation available through that broader authority.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Distinguish Linux users and groups from Kubernetes identities.
- Evaluate file, socket and privilege-elevation authority.
- Separate routine operational access from exceptional administration.
- Review credential revocation and auditable privileged actions.
