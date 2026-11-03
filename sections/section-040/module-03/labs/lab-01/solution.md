---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Remove Privileged Mode And Keep One Capability Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-03-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect And Explain

Look at the current Deployment and the capabilities of its pod:

```sh
kubectl -n starfleet get deployment relay -o yaml
kubectl -n starfleet exec deploy/relay -- grep -E 'CapBnd|NoNewPrivs|Seccomp:' /proc/1/status
```

The pod is privileged, so it holds every capability and runs without a seccomp filter. Setting `privileged: false` is the first step, because the privileged flag overrides every other restriction. Then drop `ALL` capabilities and add back the single one the workload needs. A non-root user, `allowPrivilegeEscalation: false` and `RuntimeDefault` seccomp finish the change.

Save this as `deployment-relay.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: relay
  namespace: starfleet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: relay
  template:
    metadata:
      labels:
        app: relay
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: relay
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

Apply the required change:

```sh
kubectl apply -f deployment-relay.yaml
```

## Verify The Result

Observe the actual result. A denied operation returns a nonzero status when the control works. Run denial checks separately from a shell sequence that stops on the first nonzero status.

```sh
kubectl -n starfleet rollout status deployment/relay --timeout=180s
kubectl -n starfleet exec deploy/relay -- id -u
kubectl -n starfleet exec deploy/relay -- grep -E 'CapBnd|NoNewPrivs|Seccomp:' /proc/1/status
```

Change Deployment `relay` in `starfleet` and keep its name, selector, image and command. Its pod must set `runAsNonRoot: true`, `runAsUser: 1000` and `RuntimeDefault` seccomp. Its container `relay` must set `privileged: false` and `allowPrivilegeEscalation: false`, drop `ALL` capabilities and add back only `NET_BIND_SERVICE`. The running pod must show `CapBnd` as `0000000000000400`, `NoNewPrivs: 1` and `Seccomp: 2` in `/proc/1/status`, and the Deployment rollout must be complete.

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-03-01`.

## Common pitfalls

> [!WARNING]
> The container `securityContext` holds `privileged`, `allowPrivilegeEscalation` and `capabilities`; the pod `securityContext` holds the user and the seccomp profile. For a non-root process, read `CapBnd`, because `CapEff` is empty. Pods of the old ReplicaSet keep their old settings until the rollout replaces them.
