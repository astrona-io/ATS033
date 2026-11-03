---
draft: true
exam_objectives:
- Using least-privilege identity and access management
---
# Summary

A ServiceAccount is the identity of a workload, and a pod uses the one named in `serviceAccountName`, or `default` when the field is empty. The kubelet writes the ServiceAccount token into the container, and anyone who controls the container process can use it against the API server. A dedicated ServiceAccount for each workload keeps permissions separate and keeps audit records readable.

Most pods never call the API, so they should not receive a token. The field `automountServiceAccountToken: false` turns the mount off on the ServiceAccount or on the pod, and the pod setting wins. Running pods keep what they started with, so a Deployment must roll for the change to take effect. A workload that does call the API keeps its token, bound to a Role with only the permissions it uses.

Tokens in current clusters are bound. The API server issues them through the TokenRequest API, ties them to the pod, sets an expiry and an audience, and rejects them when the pod is deleted. A projected volume lets a pod receive an extra token for another service with its own lifetime, of at least ten minutes. The command `kubectl create token` issues a short-lived token for scripts and tests.

Leftover identities need regular cleanup. The `default` ServiceAccount exists in every namespace and cannot be removed, so it must have no bindings and no token mount. Long-lived token Secrets never expire, so they should be found by their type, replaced by short-lived tokens where a system needs access, and deleted. Deleting a ServiceAccount invalidates every token issued for it.

Key facts:

- The token directory is `/var/run/secrets/kubernetes.io/serviceaccount`.
- The pod setting for `automountServiceAccountToken` overrides the ServiceAccount setting.
- A projected token has a minimum lifetime of 600 seconds.
- `kubectl get secrets --all-namespaces --field-selector type=kubernetes.io/service-account-token` finds long-lived tokens.
- A token proves who the caller is. Bindings decide what the caller may do.

<!-- astrona:playground:destroy -->
