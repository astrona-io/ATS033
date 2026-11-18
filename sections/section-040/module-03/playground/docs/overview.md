---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Guided Practice: Drop Capabilities And Block Escalation

The playground is a virtual machine (VM) that runs a one-node Kubernetes 1.35 cluster built with kubeadm. Its kernel has AppArmor enabled. This environment is separate from the graded labs. Open a shell on the VM from your own machine:

<!-- astrona:playground:renew -->

```sh
astrona ssh astro-ats-033-playground-040-03
```

You are now the user `student`. `kubectl`, the Kubernetes command-line tool, already points to the playground cluster. Check the context, which names the cluster and the user that `kubectl` uses:

```sh
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-playground-040-03
```

Look at the starting state. No hardened workload exists yet.

```sh
kubectl -n starfleet get pods
```

```text
NAME                     READY   STATUS    RESTARTS   AGE
probe-7db6ffd7d6-96mrl   1/1     Running   0          14m
probe-7db6ffd7d6-hdgrn   1/1     Running   0          14m
shuttle                  1/1     Running   0          14m
```

The pod names and ages differ in your playground.

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

```text
pod/bind-only condition met
1000
CapBnd:	0000000000000400
NoNewPrivs:	1
Seccomp:	2
```

The process runs as user `1000`. `CapBnd` holds only bit 10, `NET_BIND_SERVICE`. `NoNewPrivs: 1` comes from `allowPrivilegeEscalation: false`, and `Seccomp: 2` means a seccomp filter is active.

Create Pod `bind-only` running BusyBox as user 1000 with `runAsNonRoot: true` and `RuntimeDefault` seccomp. Its container must set `privileged: false` and `allowPrivilegeEscalation: false`, drop `ALL` capabilities and add back only `NET_BIND_SERVICE`. `CapBnd` must read `0000000000000400`. Keep the sleeping process running.

## Common pitfalls

> [!WARNING]
> - **Reading `CapEff` for a non-root process.** It is empty. Read `CapBnd`.
> - **Putting `capabilities` at pod level.** The field exists only under `containers[].securityContext`.
> - **Leaving `allowPrivilegeEscalation` unset.** It defaults to allowed.
