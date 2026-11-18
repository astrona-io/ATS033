---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Starting Environment

The lab VM runs a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node is the control plane and also runs the pods. Besides the system accounts and the platform accounts `ubuntu`, `student` and `astrona`, the node has three local accounts. `opsadmin` is the account that administrators use. `olduser` belongs to a person who left, and it still has a password and an interactive shell. `toor` is a second account with UID 0, which an old maintenance script created as a spare root login.
