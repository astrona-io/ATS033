---
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

The cluster has one node, which is the control plane and also runs the pods. kube-scheduler runs as a static pod, which is a pod that the kubelet starts from a manifest file in `/etc/kubernetes/manifests` on the node. In this cluster, the manifest `/etc/kubernetes/manifests/kube-scheduler.yaml` sets `--bind-address=0.0.0.0`, so kube-scheduler listens on port 10259 on every address of the node.

The pod `shuttle` in `starfleet-033-030-03-01` runs on the pod network. It can open a connection to port 10259 on the node's InternalIP and get an answer from the health endpoint.
