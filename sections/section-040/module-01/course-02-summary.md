---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Summary

Seccomp filters system calls, while AppArmor applies mandatory access rules to resources and operations. Their profiles complement user identity, capabilities and filesystem restrictions rather than replacing them.

Declared profiles require compatible nodes, runtime support and appropriate profile distribution. Denials should be traced to the necessary operation and corrected narrowly; disabling confinement globally hides the boundary rather than explaining the application requirement.
