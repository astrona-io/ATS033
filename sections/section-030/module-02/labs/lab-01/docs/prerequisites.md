---
draft: true
exam_objectives:
- Minimize external access to the network
---
# Prerequisites

Use astrona, kubectl, Python 3, Podman and a shell. Node inspection exercises use the containers in this environment, not the physical host.

Use a host shell with the private kubeconfig for this independent kind environment.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-02-01" || exit 1
node_name="astro-ats-033-lab-030-02-01-control-plane"
worker_name="astro-ats-033-lab-030-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers.
