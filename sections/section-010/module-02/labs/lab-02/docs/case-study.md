---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Starting Environment

The cluster has one control-plane node and one worker node. The control-plane node has three local accounts besides the system accounts. `opsadmin` is the account that administrators use. `olduser` belongs to a person who left, and it still has a password and an interactive shell. `toor` is a second account with UID 0, which an old maintenance script created as a spare root login.
