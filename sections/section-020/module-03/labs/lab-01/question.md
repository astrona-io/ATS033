---
exam_objectives:
- Using least-privilege identity and access management
---
# Question

Solve this question on: `terminal`

In `starfleet-033-020-03-01`, two Deployments run as the `default` ServiceAccount. The `monitor` Deployment must call the Kubernetes API server to list Pods, so it needs its own identity with only that permission. The `probe` Deployment never calls the API server, so it must not receive a ServiceAccount token at all. The Role `pod-reader` already exists in the namespace.

Use a host shell with the private kubeconfig for this cluster. A kubeconfig is the file that tells `kubectl`, the Kubernetes command-line tool, which cluster to use and which credentials to send.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-020-03-01" || exit 1
```

Keep this connection selected. Every script of the lab refuses a different context.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Create the ServiceAccount `monitor` in `starfleet-033-020-03-01` and bind it to the Role `pod-reader` with a RoleBinding.
2. Change the Deployment `monitor` so that its Pod runs as the ServiceAccount `monitor`.
3. Change the Deployment `probe` so that its Pod has no ServiceAccount token mounted.

## Constraints

- Keep one replica in each Deployment.
- The `monitor` Pod still needs its token, because it calls the API server.
- Do not give `monitor` access to Secrets or any write permission.

## How the answer is checked

The grader runs two checks. The first check confirms that the running `monitor` Pod uses the ServiceAccount `monitor` and has a token at `/var/run/secrets/kubernetes.io/serviceaccount/token`. It then asks `kubectl auth can-i` and expects `yes` for listing Pods and `no` for reading Secrets and for deleting Pods. The second check runs `ls` inside the running `probe` Pod and expects the directory `/var/run/secrets/kubernetes.io/serviceaccount` to be absent.
