---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Starting Environment

The cluster has one control-plane node and one worker node. The control-plane node holds an SSH server configuration: a main file that includes a drop-in directory near its top and ends with a `Match` block for a backup account, and two drop-in files. One drop-in file was added at install time and allows root logins. The other comes from a cloud image and allows password logins. The administrator account is `opsadmin`. The node image has no SSH server program, so the configuration files are the only thing to change.
