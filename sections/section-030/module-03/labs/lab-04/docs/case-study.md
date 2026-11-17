---
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

etcd runs as a static pod on the control-plane node. Its manifest `/etc/kubernetes/manifests/etcd.yaml` sets `--data-dir=/var/lib/etcd`, and the pod mounts that directory from the node. kubeadm creates the directory with mode `700`, so only `root` can read it.

In this cluster, the directory has mode `755`. Every user on the node can list it and enter it. etcd itself keeps working, because it runs as `root`.
