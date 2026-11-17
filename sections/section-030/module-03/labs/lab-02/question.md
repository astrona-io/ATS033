---
exam_objectives:
- Minimize external access to the network
---
# Question

Solve this question on: `terminal`

The API server accepts requests without credentials, as the user `system:anonymous` in the group `system:unauthenticated`. That default must stay, because health checks call `/healthz` without credentials. A review found that two RBAC bindings give such callers more than health checks: anyone who reaches port 6443 can list namespaces and can list the pods in `starfleet-033-030-03-02`.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-03-02" || exit 1
node_name="astro-ats-033-lab-030-03-02-control-plane"
worker_name="astro-ats-033-lab-030-03-02-worker"
```

Keep this connection selected. Run node commands with `podman exec "$node_name" <command>`.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Find the ClusterRoleBinding that lets `system:anonymous` list namespaces, and remove that subject from it.
2. Find the RoleBinding in `starfleet-033-030-03-02` that lets `system:unauthenticated` list pods, and remove that subject from it.
3. Confirm that a request without credentials to `/api/v1/namespaces` now gets `403`, and that `/healthz` still returns `ok`.

## Constraints

- Keep both bindings and every other subject in them: the group `ops-team` must still list namespaces, and the ServiceAccount `shuttle` must still list pods in `starfleet-033-030-03-02`.
- Do not change the API server flags. `--anonymous-auth` stays on.

## How the answer is checked

From the control-plane node, the grader sends requests without credentials to `https://127.0.0.1:6443`. It expects `401` or `403` for `/api/v1/namespaces` and for `/api/v1/namespaces/starfleet-033-030-03-02/pods`, and `200` for `/healthz`. It also reads the bindings: no ClusterRoleBinding (other than the built-in `system:public-info-viewer`) and no RoleBinding in `starfleet-033-030-03-02` may name the user `system:anonymous` or the group `system:unauthenticated` as a subject. With `kubectl auth can-i`, the group `ops-team` and the ServiceAccount `shuttle` must still get `yes`.
