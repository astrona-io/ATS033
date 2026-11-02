---
draft: true
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Guided Practice: Run With A Restricted Security Context

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-040-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-040-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect And Explain

The application and client fixtures are healthy. Complete the required change without replacing unrelated resources.

Inspect the relevant evidence:

```sh
kubectl -n starfleet get pods
kubectl -n starfleet get deployment probe -o yaml
```

Container security settings control process privileges and filesystem writes. A read-only root filesystem does not make a mounted emptyDir read-only. The Pod group setting lets the non-root process use that volume. Verify both the allowed scratch write and the denied root filesystem write.


Save this as `pod-restricted-reader.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: restricted-reader
  namespace: starfleet
spec:
  restartPolicy: Never
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: scratch
      mountPath: /scratch
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  volumes:
  - name: scratch
    emptyDir: {}
```

Apply the required change:

```sh
kubectl apply -f pod-restricted-reader.yaml
```

## Verify The Result

Observe the actual result. A denied-request command returns a nonzero status when the denial works. Run denial checks separately from a shell sequence that stops on the first nonzero status.

```sh
kubectl -n starfleet wait --for=condition=Ready pod/restricted-reader --timeout=180s
kubectl -n starfleet exec restricted-reader -- id -u
kubectl -n starfleet exec restricted-reader -- sh -c 'printf allowed > /scratch/result; cat /scratch/result'
kubectl -n starfleet exec restricted-reader -- sh -c 'printf denied > /root-file'
```

Create Pod `restricted-reader` running BusyBox as user and group 1000, with `runAsNonRoot: true`, RuntimeDefault seccomp and group-writable emptyDir `scratch` mounted at `/scratch`. Its container must disable privilege escalation, drop all capabilities and use a read-only root filesystem. Writing in scratch must work; writing `/root-file` must fail. Keep the sleeping process running.


## Common pitfalls

> [!WARNING]
> A read-only root filesystem can coexist with writable mounted scratch storage. Keep all privilege restrictions, and verify both the permitted and denied write. Running as a non-root user alone is insufficient.

Verify `/proc/1/status` reports `Seccomp: 2` and `NoNewPrivs: 1` in the running reader. This confirms an installed seccomp filter. AppArmor requires a separately available kernel implementation and profile; this exercise does not claim AppArmor coverage.
