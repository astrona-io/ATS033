---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Privileged Host Interfaces

Some of the most dangerous parts of a node have no network port. A socket file, a mounted directory or one flag on a pod gives a process the same power as a root shell on the node. This part names those interfaces, shows where to look for them on a node and in a cluster, and shows how a pod reads a file from the host through a `hostPath` volume and how Pod Security Admission stops it.

## Four ways a process reaches host authority

The **container runtime socket** is a Unix socket file, for example `/run/containerd/containerd.sock` for containerd. Whoever can write to it can ask the runtime to start any container, including a privileged container that mounts the whole host filesystem. For this reason, membership of a group that owns a runtime socket (for example the `docker` group with Docker) is equal to root access.

A **`hostPath` volume** mounts a file or directory of the node into a pod. A pod with a `hostPath` of `/` can read and change every file of the node. **Host namespaces** are set by the pod fields `hostNetwork`, `hostPID` and `hostIPC`: the pod then shares the network, the process list or the inter-process communication of the node. A **privileged container** (`securityContext.privileged: true`) has almost every Linux capability and access to the devices of the node.

The **kubelet** is the node agent that starts pods. Its API on port 10250 can run commands inside pods, so it must reject unauthenticated callers. Its configuration decides that.

## Look at the runtime socket and the kubelet settings

Select the environment and define the helper:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-010-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-010-01" || exit 1
node_name="astro-ats-033-playground-010-01-control-plane"
run_on_node() { podman exec "$node_name" "$@"; }
```

First, look at the owner and the permission bits of the containerd socket:

```sh
run_on_node ls -l /run/containerd/containerd.sock
```

The first column starts with `s` for a socket. Read the owner, the group and the mode. A mode that lets a group or all users write to the file would hand out runtime control, so the expected owner is `root`, and only `root` should be able to write.

Next, read the kubelet configuration file. Three settings protect the kubelet API. `authentication.anonymous.enabled` must be `false`, so a caller without credentials gets a rejection. `authorization.mode` must be `Webhook`, so the kubelet asks the API server whether the caller may do the action, and the default `AlwaysAllow` must not be used. `readOnlyPort` must be `0` or absent, because port 10255 serves unauthenticated read-only data:

```sh
run_on_node grep -A4 -E 'anonymous|authorization|readOnlyPort' /var/lib/kubelet/config.yaml
```

Compare each setting with the rule above. A kubeadm-created node normally sets them as required. If your output differs, the node deviates from the secure defaults, and you would correct the file and restart the kubelet with `systemctl restart kubelet`.

## Find pods that use host namespaces

The cluster side of the inventory asks which pods share the host's namespaces. `custom-columns` prints chosen fields of every pod:

```sh
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTNETWORK:.spec.hostNetwork,HOSTPID:.spec.hostPID
```

Pods that do not set a field show `<none>`. In `kube-system` several control-plane pods show `true` in the `HOSTNETWORK` column, which is required for them. Pods in `starfleet` and `outpost` should show `<none>`. Any other pod with `true` is on the list for a justification.

## Read a host file from a pod

A short experiment shows what a `hostPath` volume gives. The next file defines a pod that mounts the node's `/etc` directory read-only and sleeps.

Save this as `pod-host-reader.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: host-reader
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
    volumeMounts:
    - name: host-etc
      mountPath: /host-etc
      readOnly: true
  volumes:
  - name: host-etc
    hostPath:
      path: /etc
```

Apply it:

```sh
kubectl apply -f pod-host-reader.yaml
```

Then check the result:

```sh
kubectl -n starfleet wait --for=condition=Ready pod/host-reader --timeout=120s
kubectl -n starfleet exec host-reader -- cat /host-etc/hostname
```

The command prints the host name of the node that runs the pod, not the name of the pod. The kubelet on that node, with the container runtime, mounted the node directory into the container. The pod only read a harmless file here, but the same mount without `readOnly` and with a path of `/` would allow it to change any file on the node.

## Block it with Pod Security Admission

Pod Security Admission is a built-in admission controller of the API server. It checks every new pod against a Pod Security Standard that a namespace label selects. The `baseline` standard forbids `hostPath` volumes, host namespaces and privileged containers. The label `pod-security.kubernetes.io/enforce=baseline` makes the API server reject a pod that violates the standard. It does not remove pods that already run.

Remove the pod, label the namespace, and apply the same file again:

```sh
kubectl -n starfleet delete pod host-reader
kubectl label namespace starfleet pod-security.kubernetes.io/enforce=baseline
kubectl apply -f pod-host-reader.yaml
```

The last command fails. The error message names `PodSecurity`, the `baseline` level and the `hostPath` volume `host-etc`. The rejection comes from the API server, so the pod never reaches a node. To undo the experiment, remove the label with `kubectl label namespace starfleet pod-security.kubernetes.io/enforce-`.

You now know the interfaces that carry host authority without a port, and two checks for them: node files for the socket and the kubelet, and API queries for pods. The module has covered one cycle: list what exists, turn off what has no purpose, remove what is not needed and review the interfaces that remain.

## Common pitfalls

> [!WARNING]
> - **Treating a runtime socket like a normal file.** Write access to it equals root on the node. Check its owner and mode, and never mount it into a pod without a strong reason.
> - **Thinking `readOnly: true` makes a `hostPath` safe.** It protects the files from writes, but the pod can still read secrets such as kubelet credentials under `/var/lib/kubelet`.
> - **Expecting Pod Security Admission to remove running pods.** The `enforce` label affects new and updated pods only. Audit the existing ones with `kubectl get pods`.
> - **Changing the kubelet configuration without a restart.** The kubelet reads `/var/lib/kubelet/config.yaml` at start, so run `systemctl restart kubelet` and check the node returns to `Ready`.
