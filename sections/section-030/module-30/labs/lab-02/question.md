---
exam_objectives:
- Minimize external access to the network
---
# Remove Anonymous Access From RBAC Bindings

Allow about 10 minutes for the tasks.

Solve this question on: `terminal`

The API server accepts requests without credentials, as the user `system:anonymous` in the group `system:unauthenticated`. That default must stay, because health checks call `/healthz` without credentials. A review found that two RBAC bindings give such callers more than health checks: anyone who reaches port 6443 can list namespaces and can list the pods in `starfleet-033-030-03-02`.

The lab VM (virtual machine) runs a one-node Kubernetes cluster built with kubeadm. The node is the control plane and also runs the pods. Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-030-03-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-030-03-02`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. The requests to the API server run on the node, so they reach it on `127.0.0.1`. They change only the lab VM, not your own computer.

The time above does not count the cluster startup.

## Tasks

1. Find the ClusterRoleBinding that lets `system:anonymous` list namespaces, and remove that subject from it.
2. Find the RoleBinding in `starfleet-033-030-03-02` that lets `system:unauthenticated` list pods, and remove that subject from it.
3. Confirm that a request without credentials to `/api/v1/namespaces` now gets `403`, and that `/healthz` still returns `ok`.

## Constraints

- Keep both bindings and every other subject in them: the group `ops-team` must still list namespaces, and the ServiceAccount `shuttle` must still list pods in `starfleet-033-030-03-02`.
- Do not change the API server flags. `--anonymous-auth` stays on.

## How the answer is checked

From the node, the grader sends requests without credentials to `https://127.0.0.1:6443`. It expects `401` or `403` for `/api/v1/namespaces` and for `/api/v1/namespaces/starfleet-033-030-03-02/pods`, and `200` for `/healthz`. It also reads the bindings: no ClusterRoleBinding (other than the built-in `system:public-info-viewer`) and no RoleBinding in `starfleet-033-030-03-02` may name the user `system:anonymous` or the group `system:unauthenticated` as a subject. With `kubectl auth can-i`, the group `ops-team` and the ServiceAccount `shuttle` must still get `yes`.
