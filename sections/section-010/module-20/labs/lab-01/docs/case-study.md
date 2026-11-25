---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Starting Environment

The lab VM runs a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. The node is the control plane and also runs the pods. Its SSH server, `sshd`, runs as the `ssh` service. The main configuration file includes a drop-in directory near its top and ends with a `Match` block for a backup account. One drop-in file was added at install time and allows root logins. Another comes from the cloud image and allows password logins. The administrator account is `opsadmin`, and the platform logs in as `student` and `astrona`.
