---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Find And Fix A Blocked System Call In A seccomp Profile Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-02-03" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Find The Failing Operation

A pod that keeps restarting shows the status `CrashLoopBackOff`. The kubelet starts the container again and again, and it waits longer after each failure:

```sh
kubectl -n starfleet-033-040-02-03 get pods
```

```text
NAME                       READY   STATUS             RESTARTS     AGE
shuttle-84857569d8-7tjdr   0/1     CrashLoopBackOff   1 (9s ago)   10s
```

The container stopped with an error, so its own log is the best place to look. The `--previous` flag prints the log of the container that failed last, not the one that is starting now:

```sh
kubectl -n starfleet-033-040-02-03 logs deploy/shuttle --previous
```

```text
mv: can't rename '/tmp/manifest.new': Operation not permitted
```

`Operation not permitted` is the text for the error number `EPERM`, which is error number 1. The container runs as root and writes in its own `/tmp`, so file permissions are not the cause. A seccomp rule with `SCMP_ACT_ERRNO` and `errnoRet: 1` returns exactly this error. The `mv` command renames a file with one of the system calls `rename`, `renameat` or `renameat2`; which one it uses depends on the CPU architecture and the C library.

## Read The Profile

Check which profile the pod template uses, then read that file on the node. The kubelet adds the `localhostProfile` value to its seccomp directory, `/var/lib/kubelet/seccomp`:

```sh
kubectl -n starfleet-033-040-02-03 get deployment shuttle -o jsonpath='{.spec.template.spec.securityContext.seccompProfile}{"\n"}'
podman exec astro-ats-033-lab-040-02-03-control-plane cat /var/lib/kubelet/seccomp/profiles/cargo-guard.json
```

```text
{"localhostProfile":"profiles/cargo-guard.json","type":"Localhost"}
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["rename", "renameat", "renameat2", "chown", "fchown", "fchownat", "lchown"],
      "action": "SCMP_ACT_ERRNO",
      "errnoRet": 1
    }
  ]
}
```

The one rule blocks two groups of system calls: the three rename calls, which the workload needs, and the four calls that change the owner of a file, which the security team wants to block. Remove only the rename calls.

## Fix The Profile

Save this as `cargo-guard.json`:

```json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["chown", "fchown", "fchownat", "lchown"],
      "action": "SCMP_ACT_ERRNO",
      "errnoRet": 1
    }
  ]
}
```

Copy it over the old file on the node, and read it back to make sure the node has the new content:

```sh
podman cp cargo-guard.json astro-ats-033-lab-040-02-03-control-plane:/var/lib/kubelet/seccomp/profiles/cargo-guard.json
podman exec astro-ats-033-lab-040-02-03-control-plane cat /var/lib/kubelet/seccomp/profiles/cargo-guard.json
```

```text
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["chown", "fchown", "fchownat", "lchown"],
      "action": "SCMP_ACT_ERRNO",
      "errnoRet": 1
    }
  ]
}
```

The kubelet reads the profile file only when it creates a container. A running container keeps the filter it started with. Restart the Deployment so that the Deployment controller replaces the pod and the kubelet loads the new file:

```sh
kubectl -n starfleet-033-040-02-03 rollout restart deployment/shuttle
kubectl -n starfleet-033-040-02-03 rollout status deployment/shuttle --timeout=180s
```

```text
deployment.apps/shuttle restarted
Waiting for deployment "shuttle" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "shuttle" rollout to finish: 1 old replicas are pending termination...
deployment "shuttle" successfully rolled out
```

The rollout waits for the readiness probe, so `successfully rolled out` already means that `/tmp/manifest` exists. When the old pod is gone, one pod is left:

```sh
kubectl -n starfleet-033-040-02-03 get pods
```

```text
NAME                      READY   STATUS    RESTARTS   AGE
shuttle-7f9968c58-8vppp   1/1     Running   0          36s
```

## Verify The Result

The value `2` in the `Seccomp:` line means that the main process runs with a seccomp filter. The file `/tmp/manifest` shows that the rename in the loop works:

```sh
kubectl -n starfleet-033-040-02-03 exec deploy/shuttle -- grep Seccomp: /proc/1/status
kubectl -n starfleet-033-040-02-03 exec deploy/shuttle -- cat /tmp/manifest
```

```text
Seccomp:	2
Tue Nov 17 22:10:52 UTC 2026
```

The last check must fail. The container runs as root, so without the seccomp rule `chown` would work:

```sh
kubectl -n starfleet-033-040-02-03 exec deploy/shuttle -- chown 1000 /tmp/manifest
```

```text
chown: /tmp/manifest: Operation not permitted
command terminated with exit code 1
```

The kernel rejected the `chown` system call because of the rule that is still in the profile.

The restart is not the only way the new profile takes effect. While the container is in `CrashLoopBackOff`, the kubelet creates a new container at each restart, and it reads the profile file again at that moment. In the live run of this lab, a crash-looping pod became ready about 20 seconds after the file was copied. The rollout restart is still the clear and quick choice, because it does not depend on the back-off timer.

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-02-03`.

## Common pitfalls

> [!WARNING]
> - Removing the whole rule. The pod runs again, but `chown` is no longer blocked.
> - Removing only `rename`. Some CPU architectures, such as arm64, have no `rename` system call, so `mv` uses `renameat` or `renameat2` there and the error stays. Remove all three rename calls.
> - Switching the pod to `Unconfined` to make it start. That removes every rule, including the one the security team asked for.
> - Reading `kubectl logs` without `--previous` while the container is starting again. The new container may not have printed the error yet.
