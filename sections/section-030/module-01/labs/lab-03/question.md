---
exam_objectives:
- Minimize external access to the network
---
# Question

Solve this question on: `terminal`

The namespace `starfleet-033-030-01-03` accepts traffic from everywhere, and the `drifter` in `outpost-033-030-01-03` can reach every pod in it. The namespace runs the Deployment `probe` behind the Service `probe` (port 80 to container port 8080), a single pod `beacon` on port 8080 and the client pod `shuttle`. Only `shuttle` should reach `probe`, and nothing should reach any other pod in the namespace.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-01-03" || exit 1
```

Keep this connection selected.

Allow about 12 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Create a NetworkPolicy in `starfleet-033-030-01-03` that selects every pod in the namespace and denies all incoming traffic.
2. Create a second NetworkPolicy that lets pods with the label `app: shuttle` reach pods with the label `app: probe` on TCP port 8080.
3. Confirm that `shuttle` gets `version=v1` from the Service `probe`, and that requests from `drifter` to `probe` and from both clients to `beacon` time out.

## Constraints

- Do not change, delete or relabel the pods, the Deployment or the Service.
- Do not restrict outgoing (egress) traffic.

## How the answer is checked

The first check looks for a NetworkPolicy in the namespace with an empty `podSelector`, `Ingress` in `policyTypes` and no ingress rules. It then sends requests from `shuttle` and from `drifter` to the pod IP of `beacon` on port 8080 and expects both to time out. The second check sends a request from `shuttle` to the Service `probe` and expects `version=v1`, then sends a request from `drifter` to the same Service and expects a timeout.
