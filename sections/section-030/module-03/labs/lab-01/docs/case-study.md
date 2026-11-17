---
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

The cluster has one control-plane node and one worker node. kube-scheduler runs as a static pod, which is a pod that the kubelet starts from a manifest file in `/etc/kubernetes/manifests` on the node. In this cluster, the manifest `/etc/kubernetes/manifests/kube-scheduler.yaml` sets `--bind-address=0.0.0.0`, so kube-scheduler listens on port 10259 on every address of the control-plane node.

The pod `shuttle` in `starfleet-033-030-03-01` runs on the worker node. It can open a connection to port 10259 on the control-plane node's InternalIP and get an answer from the health endpoint.
