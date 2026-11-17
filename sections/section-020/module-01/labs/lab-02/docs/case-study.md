---
exam_objectives:
- Using least-privilege identity and access management
---
# Starting Environment

The cluster has one control-plane node and no application workloads. The node has two normal accounts with a password: `departed-user` and `pilot`. Both accounts use the shell `/bin/bash` and never expire.

`departed-user` belongs to a person who has left. The task is to disable that account without deleting it, and to leave `pilot` unchanged.
