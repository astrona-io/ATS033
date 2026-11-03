---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Summary

Every control-plane port needs two controls. A network rule limits who can connect, and an authentication and authorization setting limits what a connected caller can do. The API server uses port 6443 and must accept remote clients. The kubelet uses port 10250 on every node. etcd uses 2379 for clients and 2380 for peers, and only the API servers and the other members need them. The controller manager and the scheduler use ports 10257 and 10259 and are bound to the loopback address in a kubeadm cluster.

The command `ss -tlnp` shows what listens and on which address, and the manifests in `/etc/kubernetes/manifests` show the flag behind each listener. A wildcard address means the port accepts connections on every interface, and a loopback address means only the node itself. The bind address and the firewall are separate layers, and a cluster uses both.

The API server treats a request with no credentials as the user `system:anonymous` when `--anonymous-auth` is `true`. By default that user may read only `/healthz`, `/livez`, `/readyz` and `/version`. The flag `--authorization-mode` lists the authorizers, and `Node,RBAC` is the normal value. `AlwaysAllow` is never acceptable. A request fails with 401 when the caller is unknown and with 403 when the caller is known and not allowed.

The kubelet needs three settings: anonymous access off, authentication through the cluster certificate authority and tokens, and authorization mode `Webhook`. Without them, any caller that reaches port 10250 can list pods and run commands in containers. The kubelet reads its configuration file only at start, so a change needs a restart. etcd stores every Secret, so it requires client certificates and accepts connections only from the API servers and its own members.

Key facts:

- A 401 status means the caller is not authenticated, and a 403 status means the caller is not allowed.
- `--anonymous-auth` defaults to `true`, and the default role lets anonymous users read only a few information paths.
- Kubelet `authorization.mode: AlwaysAllow` together with anonymous access gives full control of the node.
- The kubelet changes its behaviour only after a restart.
- etcd needs `--client-cert-auth=true`, and only the API servers need port 2379.

<!-- astrona:playground:destroy -->
