---
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

The cluster has one control-plane node and one worker node. The API server accepts requests without credentials and gives them the user name `system:anonymous` and the group `system:unauthenticated`. This default keeps `/healthz` open for health checks.

Two RBAC (role-based access control) bindings in this cluster give anonymous callers more than that. The ClusterRoleBinding `namespace-reader` gives the ClusterRole `namespace-reader` to the group `ops-team` and to the user `system:anonymous`. The RoleBinding `pod-reader` in `starfleet-033-030-03-02` gives the Role `pod-reader` to the ServiceAccount `shuttle` and to the group `system:unauthenticated`. A request without credentials to port 6443 can therefore list namespaces and list the pods in that namespace.
