# Summary

A ServiceAccount is the identity of a workload. A pod uses the ServiceAccount named in `serviceAccountName`, or `default` when the field is empty. The kubelet writes the ServiceAccount token into the container, and anyone who controls the container process can use that token against the API server. A dedicated ServiceAccount for each workload keeps the permissions apart and keeps the audit records readable.

Most pods never call the API, so they should not get a token. The field `automountServiceAccountToken: false` turns the mount off, either on the ServiceAccount or on the pod, and the pod setting wins. Running pods keep what they started with, so a Deployment must roll before the change takes effect. A workload that does call the API keeps its token, and it gets a Role with only the permissions it uses.

Tokens in current clusters are bound. The API server issues them through the TokenRequest API, ties them to the pod, and sets an expiry time and an audience. It rejects them when the pod is deleted. A projected volume lets a pod get an extra token for another service, with its own lifetime of at least ten minutes. The command `kubectl create token` issues a short-lived token for scripts and tests.

Leftover identities need regular cleanup. The `default` ServiceAccount exists in every namespace and cannot be removed, so it must have no bindings and no token mount. Long-lived token Secrets never expire. Find them by their type, replace them with short-lived tokens where a system needs access, and delete them. Deleting a ServiceAccount makes every token issued for it invalid.

Key facts to remember:

- The token directory is `/var/run/secrets/kubernetes.io/serviceaccount`.
- The pod setting for `automountServiceAccountToken` overrides the ServiceAccount setting.
- A projected token has a minimum lifetime of 600 seconds.
- `kubectl get secrets --all-namespaces --field-selector type=kubernetes.io/service-account-token` finds long-lived tokens.
- A token proves who the caller is. Bindings decide what the caller may do.

<!-- astrona:playground:destroy -->
