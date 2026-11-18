---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The cluster has one node, `astro-ats-033-lab-040-01-02`. It is the control plane and also runs the pods. The namespace `starfleet-033-040-01-02` exists and is empty. The kernel of the node has AppArmor enabled, and `apparmor_parser` is installed. No custom profile is loaded.

AppArmor is a Linux security module. It confines a program with a profile, a list of the files, capabilities and network access the program may use. Each node has its own kernel list of loaded profiles, so in a cluster with more nodes a profile must be loaded on every node that can run the pod.
