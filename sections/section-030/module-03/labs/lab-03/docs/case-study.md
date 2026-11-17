---
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

The cluster has one control-plane node and one worker node. The kubelet on each node reads its settings from `/var/lib/kubelet/config.yaml` and serves an HTTPS API on port 10250. The API server uses that API for `kubectl logs`, `kubectl exec` and node metrics.

On the worker node, the file sets `authentication.anonymous.enabled: true` and `authorization.mode: AlwaysAllow`. With these settings the kubelet accepts a request without credentials as `system:anonymous` and allows it without asking the API server. The namespace `starfleet-033-030-03-03` holds the ServiceAccount `metrics-reader`, which has no RBAC (role-based access control) permissions.
