---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Fix A Pod That References A Missing seccomp Profile Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-01-04)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-01-04" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Find The Cause

A pod that never reaches `Running` usually tells you why in its status and its events. Start with the status:

```sh
kubectl -n starfleet-033-040-01-04 get pods
```

```text
NAME                      READY   STATUS                 RESTARTS   AGE
shuttle-bdb945688-52h2t   0/1     CreateContainerError   0          11s
```

`CreateContainerError` means the kubelet asked the container runtime (containerd) to create the container, and the runtime refused. The events say why. The command below prints only the `Events:` part of the description; the rest is left out:

```sh
kubectl -n starfleet-033-040-01-04 describe pods -l app=shuttle | sed -n '/^Events:/,$p'
```

```text
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  11s                default-scheduler  Successfully assigned starfleet-033-040-01-04/shuttle-bdb945688-52h2t to astro-ats-033-lab-040-01-04-control-plane
  Normal   Pulled     10s (x2 over 10s)  kubelet            spec.containers{shuttle}: Container image "docker.io/library/busybox:1.37.0" already present on machine and can be accessed by the pod
  Warning  Failed     10s (x2 over 10s)  kubelet            spec.containers{shuttle}: Error: failed to create containerd container: cannot load seccomp profile "/var/lib/kubelet/seccomp/profiles/shutle-guard.json": open /var/lib/kubelet/seccomp/profiles/shutle-guard.json: no such file or directory
```

The kubelet builds the full path from the kubelet seccomp directory, `/var/lib/kubelet/seccomp`, and the `localhostProfile` value. containerd could not open that file. Compare the value in the Deployment with the files on the node:

```sh
kubectl -n starfleet-033-040-01-04 get deployment shuttle -o jsonpath='{.spec.template.spec.securityContext.seccompProfile}{"\n"}'
podman exec astro-ats-033-lab-040-01-04-control-plane ls /var/lib/kubelet/seccomp/profiles
```

```text
{"localhostProfile":"profiles/shutle-guard.json","type":"Localhost"}
shuttle-guard.json
```

The Deployment asks for `shutle-guard.json`, with one `t`. The approved file is `shuttle-guard.json`. The profile is installed correctly; the reference to it is wrong.

## Fix The Deployment

Change only the `localhostProfile` value in the pod template. A JSON patch replaces that one field and leaves the rest of the Deployment as it is:

```sh
kubectl -n starfleet-033-040-01-04 patch deployment shuttle --type=json -p='[{"op":"replace","path":"/spec/template/spec/securityContext/seccompProfile/localhostProfile","value":"profiles/shuttle-guard.json"}]'
```

```text
deployment.apps/shuttle patched
```

The change to the pod template makes the Deployment controller create a new ReplicaSet, which creates a new pod. Wait for the rollout:

```sh
kubectl -n starfleet-033-040-01-04 rollout status deployment/shuttle --timeout=180s
```

```text
Waiting for deployment spec update to be observed...
Waiting for deployment "shuttle" rollout to finish: 0 out of 1 new replicas have been updated...
Waiting for deployment "shuttle" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "shuttle" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "shuttle" rollout to finish: 1 old replicas are pending termination...
deployment "shuttle" successfully rolled out
```

The old pod is removed a few seconds later. When only one pod is left, it runs:

```sh
kubectl -n starfleet-033-040-01-04 get pods
```

```text
NAME                      READY   STATUS    RESTARTS   AGE
shuttle-c85fc99bb-58vw7   1/1     Running   0          10s
```

## Verify The Result

`kubectl exec deploy/shuttle` picks a pod of the Deployment for you, so you do not need to copy the new pod name. The value `2` in the `Seccomp:` line means the container runtime installed a filter on the main process:

```sh
kubectl -n starfleet-033-040-01-04 exec deploy/shuttle -- grep Seccomp /proc/1/status
```

```text
Seccomp:	2
Seccomp_filters:	1
```

The approved profile blocks the system calls that change file permissions. The next command is expected to fail, so run it on its own:

```sh
kubectl -n starfleet-033-040-01-04 exec deploy/shuttle -- sh -c 'touch /tmp/flight-plan && chmod 600 /tmp/flight-plan'
```

```text
chmod: /tmp/flight-plan: Operation not permitted
command terminated with exit code 1
```

`touch` worked, so the file exists and the user is allowed to write it. The kernel rejected the `chmod` system call because of the seccomp rule.

Another fix also works: copy the approved file to the misspelled name on the node. The kubelet retries the failed container, so the old pod then starts under the same profile content. Fixing the Deployment is the better choice, because the next person who reads it sees the real file name.

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-01-04`.

## Common pitfalls

> [!WARNING]
> - Switching to `RuntimeDefault` or `Unconfined` to make the pod start. The pod runs, but `chmod` is no longer blocked.
> - Running `kubectl exec` with the old pod name right after the rollout. That pod is terminating, and the command fails with `container not found`.
> - Looking only at `kubectl get pods`. The status says `CreateContainerError`, but only the events show which file the runtime could not open.
