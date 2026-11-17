---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Starting Environment

The cluster has one control-plane node and one worker node. The namespace `starfleet-033-040-01-02` exists and is empty. The start of the lab has checked that AppArmor is enabled in the kernel of both nodes and that `apparmor_parser` is available in each node. No custom profile is loaded.

AppArmor is a Linux security module. It confines a program with a profile, a list of the files, capabilities and network access the program may use. Each node has its own kernel list of loaded profiles, so a profile loaded on one node does not exist on the other. The scheduler may place the new pod on either node.
