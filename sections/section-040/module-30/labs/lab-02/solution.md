---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Set An AppArmor Profile For One Container Solution

The lab runs in a VM (virtual machine) with a one-node Kubernetes cluster built with kubeadm. Open a shell on the lab VM and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-040-03-02
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-lab-040-03-02
```

You are logged in as the `student` user. This task needs only `kubectl`, so no command on this page uses `sudo`. The output on this page comes from a run on 2026-11-18. Pod ages and restart counts in your output will differ.

## Find Why console Restarts

Start with the pod status. The `READY` column shows that only one of the two containers is ready, and the `RESTARTS` column grows over time:

```sh
kubectl -n starfleet-033-040-03-02 get pod bridge
```

```text
NAME     READY   STATUS             RESTARTS     AGE
bridge   1/2     CrashLoopBackOff   1 (6s ago)   7s
```

The logs of the last run of `console` show the reason:

```sh
kubectl -n starfleet-033-040-03-02 logs bridge -c console --previous
```

```text
sh: can't create /tmp/console.log: Permission denied
```

The container runs as root, so normal file permissions allow the write. The block comes from AppArmor. Print the profile settings of the pod and of each container:

```sh
kubectl -n starfleet-033-040-03-02 get pod bridge -o jsonpath='{.spec.securityContext.appArmorProfile}{"\n"}{.spec.containers[*].securityContext}{"\n"}'
```

```text
{"localhostProfile":"k8s-deny-tmp-write","type":"Localhost"}

```

The first line shows `Localhost` and `k8s-deny-tmp-write`. The second line is empty, because no container sets its own value. The pod value therefore applies to both containers, and the rule `deny /tmp/** w` stops `console`.

## Create The Pod Again

The `securityContext` of a running pod cannot change; the API server rejects an update to it. So delete the pod and create it again with the corrected fields. The pod level gets `RuntimeDefault`, the default profile of the container runtime. The `logger` container gets its own `Localhost` value, which overrides the pod value for that container only.

Delete the old pod first. The command can take up to about 30 seconds, the default grace period, because the `sleep` container ignores the `SIGTERM` signal and the container runtime (`runc`) then sends `SIGKILL`. The profile has the rule `signal (receive) peer=runc,`, so the kernel lets that signal through:

```sh
kubectl -n starfleet-033-040-03-02 delete pod bridge
```

```text
pod "bridge" deleted from starfleet-033-040-03-02 namespace
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

```text
pod/bridge created
```

Then check the result:

```sh
kubectl -n starfleet-033-040-03-02 wait --for=condition=Ready pod/bridge --timeout=180s
```

```text
pod/bridge condition met
```

## Verify Each Container

`/proc/1/attr/current` shows the AppArmor label of the main process in a container. In `console` it now shows the default profile of containerd:

```sh
kubectl -n starfleet-033-040-03-02 exec bridge -c console -- cat /proc/1/attr/current
```

```text
cri-containerd.apparmor.d (enforce)
```

A write under `/tmp` in `console` works. The command prints nothing and returns exit code 0:

```sh
kubectl -n starfleet-033-040-03-02 exec bridge -c console -- touch /tmp/console-check
```

In `logger` the label is the custom profile:

```sh
kubectl -n starfleet-033-040-03-02 exec bridge -c logger -- cat /proc/1/attr/current
```

```text
k8s-deny-tmp-write (enforce)
```

The same write fails there:

```sh
kubectl -n starfleet-033-040-03-02 exec bridge -c logger -- touch /tmp/logger-check
```

```text
touch: /tmp/logger-check: Permission denied
command terminated with exit code 1
```

Both containers share the pod, but the kernel confines each process with its own profile.

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-03-02`.

## Common pitfalls

> [!WARNING]
> - Using `kubectl edit` or `kubectl apply` on the running pod. The API server rejects a change to the pod `securityContext`, so the pod must be created again.
> - Removing the pod-level field instead of setting `RuntimeDefault`. The grader expects `RuntimeDefault` at the pod level, and an explicit value documents the intent.
> - Putting the `Localhost` value on the wrong container. The container value only overrides the pod value for that one container.
