---
exam_objectives:
- Using least-privilege identity and access management
---
# Prerequisites

Use `astrona`, `kubectl`, Podman and a shell. Node commands run inside the node container of this lab, not on your own machine.

A kubeconfig is the file that tells `kubectl`, the Kubernetes command-line tool, which cluster to use and which credentials to send. Select the private kubeconfig of this lab:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-01-02" || exit 1
node_name="astro-ats-033-lab-020-01-02-control-plane"
```

Keep this connection selected. Run node commands with `podman exec "$node_name" ...` and on no other container.
