---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Guided Practice: Drop Capabilities And Block Escalation

Use a host shell with this playground's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the graded labs.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-040-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-040-03" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the playground refuses a different context.

Look at the starting state. No hardened workload exists yet.

```sh
kubectl -n starfleet get pods
```

Save this as `pod-bind-only.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: bind-only
  namespace: starfleet
spec:
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: shell
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
```

Apply it:

```sh
kubectl apply -f pod-bind-only.yaml
```

Then check the result:

```sh
kubectl -n starfleet wait --for=condition=Ready pod/bind-only --timeout=180s
kubectl -n starfleet exec bind-only -- id -u
kubectl -n starfleet exec bind-only -- grep -E 'Seccomp:|NoNewPrivs|CapBnd' /proc/1/status
```

Create Pod `bind-only` running BusyBox as user 1000 with `runAsNonRoot: true` and `RuntimeDefault` seccomp. Its container must set `privileged: false` and `allowPrivilegeEscalation: false`, drop `ALL` capabilities and add back only `NET_BIND_SERVICE`. `CapBnd` must read `0000000000000400`. Keep the sleeping process running.

## Common pitfalls

> [!WARNING]
> - **Reading `CapEff` for a non-root process.** It is empty. Read `CapBnd`.
> - **Putting `capabilities` at pod level.** The field exists only under `containers[].securityContext`.
> - **Leaving `allowPrivilegeEscalation` unset.** It defaults to allowed.
