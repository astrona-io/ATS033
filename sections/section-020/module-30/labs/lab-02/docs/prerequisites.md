---
exam_objectives:
- Using least-privilege identity and access management
---
# Prerequisites

Use `astrona`, `kubectl` and a shell. The step that reads the token uses `base64` and `python3` on your machine. This lab changes only Kubernetes objects; it runs no node commands.

A kubeconfig is the file that tells `kubectl`, the Kubernetes command-line tool, which cluster to use and which credentials to send. Select the private kubeconfig of this lab:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-03-02" || exit 1
```

Keep this connection selected.
