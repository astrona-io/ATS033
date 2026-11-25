# Profile Types, Locations And The Unconfined Risk

Every pod starts as a Linux process that shares the kernel of its node. If that process may call every syscall, then every flaw in a rarely used kernel feature is reachable from inside the container. A seccomp profile makes that reachable part of the kernel smaller before the application starts.

On this page, you see who installs the filter and which three profile types exist. You also learn where the kubelet looks for a profile file, and what you give up when a pod runs without a filter.

## Who installs the filter

A seccomp filter is installed in the process itself. The container runtime (containerd in a `kind` node) builds the profile from the pod specification and passes it to the low-level runtime `runc`. `runc` loads the filter into the kernel just before it starts the application. From that moment, the kernel checks every syscall of that process and of all its child processes.

The process can add stricter filters, but it can never remove one. So the application cannot lift the restriction that the runtime placed on it.

The kubelet is the node agent that starts the pod. It does not filter anything itself. It has three jobs: it finds the profile file for a `Localhost` profile, it passes the profile to the runtime, and it applies the node-wide default when a pod chooses nothing.

![Diagram: the kubelet finds the profile and passes it to containerd, runc loads the filter into the kernel, and the kernel checks every syscall of the container process](images/who-installs-the-filter.svg)

The drawing shows the chain on one node. The kubelet and containerd only hand the profile on, `runc` loads it, and the kernel does the checking.

The seccomp filter never looks at file names or addresses. It decides on the syscall number and on its numeric arguments only.

## The three profile types

Now that you know who installs the filter, the next question is how a pod asks for one. The field `seccompProfile` in a `securityContext` selects the profile. It exists at pod level, where it applies to every container. It also exists at container level, where it overrides the pod value for that container.

The field takes one of three types:

- `RuntimeDefault` uses the default profile that ships with the container runtime. It denies a list of syscalls that are dangerous or that normal applications do not need, and it allows the rest. It is the correct starting point for almost every workload.
- `Localhost` uses a profile file that exists on the node. The field `localhostProfile` names the file relative to the kubelet seccomp directory.
- `Unconfined` installs no filter. The process may call every syscall that the kernel offers.

The kubelet seccomp directory is `/var/lib/kubelet/seccomp`, unless the kubelet is started with another root directory. A `localhostProfile` value is always relative to it. If the file is `/var/lib/kubelet/seccomp/profiles/audit.json`, the value is `profiles/audit.json`. A value with a leading slash is an absolute path, and the kubelet does not accept it as a profile name.

![Diagram: the full file path /var/lib/kubelet/seccomp/profiles/audit.json splits into the kubelet seccomp directory and the localhostProfile value profiles/audit.json](images/localhost-profile-path.svg)

The drawing shows how the full path splits. The kubelet adds its seccomp directory, and the pod gives only the rest of the path.

A pod that sets no `seccompProfile` does not automatically get `RuntimeDefault`. Without the kubelet setting `seccompDefault: true`, the pod runs as `Unconfined`. With that setting, the kubelet applies `RuntimeDefault` to every container that has no profile of its own.

The setting is a kubelet option, so each node needs it. A cluster can have nodes where it is on and nodes where it is off.

![Diagram: the kubelet uses the container seccompProfile if it is set, else the pod value, else RuntimeDefault when seccompDefault is true on the node, and Unconfined when it is false](images/profile-resolution-order.svg)

The drawing shows the order in which the kubelet picks the profile: the container value first, the pod value second, and the node default last.

## What Unconfined costs

With the rules for picking a profile in place, it is worth seeing what the weakest choice costs. `Unconfined` is the lack of a restriction, not a neutral setting. A kernel vulnerability in a syscall that `RuntimeDefault` would have denied becomes reachable from the container.

A container that runs as `privileged: true` also runs without a filter. A privileged container is allowed to change the node, and the runtime does not apply the default profile to it.

Pod Security Admission reflects this. Pod Security Admission is the built-in admission controller that checks pods against the Pod Security levels. The `baseline` level rejects an explicit `Unconfined` profile, and the `restricted` level accepts only `RuntimeDefault` or `Localhost`.

The cost of a filter is small. `RuntimeDefault` was designed to keep ordinary applications working, so adding it rarely breaks anything. A pod that fails under `RuntimeDefault` is unusual. The reason is then a syscall that the application needs and that the default list denies. The right answer is a `Localhost` profile that allows that one syscall, not `Unconfined`.

## Compare the three types on a node

The rules are clearer when you see them on a real node. You will start three pods that differ only in the profile, and read the process state of each. Select the environment first:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-040-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-040-02" || exit 1
node_name="astro-ats-033-playground-040-02-control-plane"
```

First, check whether the kubelet of this node applies a default. The kubelet configuration is a file on the node. If the command prints nothing, the setting is not present, and its default `false` applies:

```sh
podman exec "$node_name" grep -i seccompDefault /var/lib/kubelet/config.yaml
```

Save this as `pods-seccomp-types.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-runtime
  namespace: starfleet
spec:
  restartPolicy: Never
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: shell
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
---
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-unset
  namespace: starfleet
spec:
  restartPolicy: Never
  containers:
  - name: shell
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
---
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-privileged
  namespace: starfleet
spec:
  restartPolicy: Never
  containers:
  - name: shell
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    securityContext:
      privileged: true
```

Apply it and wait for the pods:

```sh
kubectl apply -f pods-seccomp-types.yaml
kubectl -n starfleet wait --for=condition=Ready pod/seccomp-runtime pod/seccomp-unset pod/seccomp-privileged --timeout=120s
```

Then read the `Seccomp` line of the main process in each pod:

```sh
for pod_name in seccomp-runtime seccomp-unset seccomp-privileged; do
  printf '%s: ' "$pod_name"
  kubectl -n starfleet exec "$pod_name" -- grep Seccomp: /proc/1/status
done
```

The line `Seccomp:` shows the mode of the process:

- `0` means no filter.
- `1` means the old strict mode.
- `2` means a filter is installed.

The pod `seccomp-runtime` reports `2`, because the runtime installed its default filter. The pod `seccomp-privileged` reports `0`, because a privileged container runs without a filter. The pod `seccomp-unset` follows the node default that you read above. It reports `0` when the kubelet has no `seccompDefault: true`, and `2` when it has.

![Diagram: three pods on one node, seccomp-runtime reports Seccomp 2, seccomp-unset reports 0 or 2 depending on seccompDefault, and seccomp-privileged reports Seccomp 0](images/three-pods-seccomp-mode.svg)

The drawing sums up the three results. Only the explicit `RuntimeDefault` pod is sure to have a filter on every node.

You can also read what the API server stored, which is the value that the kubelet resolves. For the unset pod, the field is empty. This proves that the filter, when present, came from the kubelet default and not from the pod:

```sh
kubectl -n starfleet get pod seccomp-unset -o jsonpath='{.spec.securityContext.seccompProfile}{"\n"}'
```

Remove the pods when you are done:

```sh
kubectl -n starfleet delete pod seccomp-runtime seccomp-unset seccomp-privileged
```

## Where Localhost profiles live

The two built-in types need nothing on the node, but `Localhost` does. A `Localhost` profile is a plain file on each node, under the directory you saw above. The kubelet reads it when it creates the container. If the file is missing on the node that runs the pod, the container does not start.

This makes node preparation part of the work. The file must be on every node where the pod can be scheduled. A new or replaced node must receive it before pods that need it arrive.

You now know the three profile types, the order in which the kubelet resolves them, and why a missing profile is a risk and not a convenience. The open question is what a profile file contains and how to write one.

## Common pitfalls

> [!WARNING]
> - **Assuming a pod without `seccompProfile` is filtered.** Only the kubelet setting `seccompDefault: true` adds `RuntimeDefault` for such a pod.
> - **Writing an absolute path in `localhostProfile`.** The value is relative to `/var/lib/kubelet/seccomp`.
> - **Treating `privileged: true` as a filtered container.** A privileged container runs without a seccomp filter.
> - **Setting `Unconfined` to silence one error.** It removes the protection for every syscall, not only for the one that failed.
> - **Setting the profile at pod level and forgetting a container override.** A container-level value replaces the pod value.
