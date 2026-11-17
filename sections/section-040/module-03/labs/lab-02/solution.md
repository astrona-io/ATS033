---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Set An AppArmor Profile For One Container Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-03-02" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

This walkthrough has no command output. The lab needs a host kernel with AppArmor, and it has not yet run on such a host. Each step says what a correct result contains, so you can compare your own output with it.

## Find Why console Restarts

Start with the pod status. The `READY` column shows `1/2` or `0/2`, and the `RESTARTS` column grows over time:

```sh
kubectl -n starfleet-033-040-03-02 get pod bridge
```

The logs of the last run of `console` show the reason. A correct result is a shell message that says `/tmp/console.log` cannot be created, with `Permission denied`:

```sh
kubectl -n starfleet-033-040-03-02 logs bridge -c console --previous
```

The container runs as root, so normal file permissions allow the write. The block comes from AppArmor. Print the profile settings of the pod and of each container:

```sh
kubectl -n starfleet-033-040-03-02 get pod bridge -o jsonpath='{.spec.securityContext.appArmorProfile}{"\n"}{.spec.containers[*].securityContext}{"\n"}'
```

The first line shows `Localhost` and `k8s-deny-tmp-write`. The second line is empty, because no container sets its own value. The kubelet therefore applies the pod value to both containers, and the rule `deny /tmp/** w` stops `console`.

## Create The Pod Again

The `securityContext` of a running pod cannot change; the API server rejects an update to it. So delete the pod and create it again with the corrected fields. The pod level gets `RuntimeDefault`, the default profile of the container runtime. The `logger` container gets its own `Localhost` value, which overrides the pod value for that container only.

Delete the old pod first:

```sh
kubectl -n starfleet-033-040-03-02 delete pod bridge
```

Save this as `pod-bridge.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: bridge
  namespace: starfleet-033-040-03-02
spec:
  restartPolicy: Always
  securityContext:
    appArmorProfile:
      type: RuntimeDefault
  containers:
  - name: console
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - while true; do date > /tmp/console.log || exit 1; sleep 5; done
    readinessProbe:
      exec:
        command:
        - cat
        - /tmp/console.log
      periodSeconds: 5
  - name: logger
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: k8s-deny-tmp-write
```

Apply it:

```sh
kubectl apply -f pod-bridge.yaml
```

Then check the result:

```sh
kubectl -n starfleet-033-040-03-02 wait --for=condition=Ready pod/bridge --timeout=180s
```

A correct result is the line `pod/bridge condition met`.

## Verify Each Container

`/proc/1/attr/current` shows the AppArmor label of the main process in a container. In `console` it now shows the default profile of containerd, `cri-containerd.apparmor.d (enforce)`, and a write under `/tmp` works with no output:

```sh
kubectl -n starfleet-033-040-03-02 exec bridge -c console -- cat /proc/1/attr/current
kubectl -n starfleet-033-040-03-02 exec bridge -c console -- touch /tmp/console-check
```

In `logger` the label reads `k8s-deny-tmp-write (enforce)`, and the same write fails with `Permission denied`:

```sh
kubectl -n starfleet-033-040-03-02 exec bridge -c logger -- cat /proc/1/attr/current
kubectl -n starfleet-033-040-03-02 exec bridge -c logger -- touch /tmp/logger-check
```

Both containers share the pod, but the kernel confines each process with its own profile.

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-03-02`.

## Common pitfalls

> [!WARNING]
> - Using `kubectl edit` or `kubectl apply` on the running pod. The API server rejects a change to the pod `securityContext`, so the pod must be created again.
> - Removing the pod-level field instead of setting `RuntimeDefault`. The grader expects `RuntimeDefault` at the pod level, and an explicit value documents the intent.
> - Putting the `Localhost` value on the wrong container. The container value only overrides the pod value for that one container.
