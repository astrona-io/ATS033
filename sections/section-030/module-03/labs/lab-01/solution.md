---
exam_objectives:
- Minimize external access to the network
---
# Bind The Scheduler To Loopback Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-03-01" || exit 1
node_name="astro-ats-033-lab-030-03-01-control-plane"
worker_name="astro-ats-033-lab-030-03-01-worker"
```

Keep this connection selected.

## Step 1: Read the listeners

The tool `ss` lists the sockets of a host. With `-tlnp` it shows the listening TCP sockets, with numeric addresses and the owning process. Read the listeners of kube-controller-manager (port 10257) and kube-scheduler (port 10259) on the control-plane node:

```sh
podman exec "$node_name" ss -tlnp | grep -E ':(10257|10259) '
```

```text
LISTEN 0      4096       127.0.0.1:10257      0.0.0.0:*    users:(("kube-controller",pid=563,fd=4))
LISTEN 0      4096               *:10259            *:*    users:(("kube-scheduler",pid=1727,fd=4))
```

kube-controller-manager listens on `127.0.0.1` only. kube-scheduler listens on `*`, which means every address of the node.

## Step 2: Find the flag

kube-scheduler is a static pod, so the kubelet on the node starts it from a manifest file. Read the bind address in that file and on the running process:

```sh
podman exec "$node_name" grep -- --bind-address /etc/kubernetes/manifests/kube-scheduler.yaml
podman exec "$node_name" pgrep -a kube-scheduler
```

```text
    - --bind-address=0.0.0.0
1727 kube-scheduler --authentication-kubeconfig=/etc/kubernetes/scheduler.conf --authorization-kubeconfig=/etc/kubernetes/scheduler.conf --bind-address=0.0.0.0 --feature-gates=KubeletInUserNamespace=true --kubeconfig=/etc/kubernetes/scheduler.conf --leader-elect=true
```

Both show `--bind-address=0.0.0.0`. The manifest is the place to fix it: a change made with `kubectl edit` on the mirror pod in `kube-system` does not reach the kubelet.

## Step 3: Prove that the port is open to other nodes

Read the control-plane address and send a request from `shuttle`, which runs on the worker node:

```sh
NODE_IP="$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
kubectl -n starfleet-033-030-03-01 exec shuttle -- wget -q -T 3 -O- "https://$NODE_IP:10259/healthz"
```

```text
wget: note: TLS certificate validation not implemented
ok
```

The health endpoint answers a pod on another node. busybox `wget` does not check the certificate, so the first line is only a note.

## Step 4: Fix the manifest

Change the flag in the manifest. `sed -i` edits the file in place:

```sh
podman exec "$node_name" sed -i 's/--bind-address=0.0.0.0/--bind-address=127.0.0.1/' /etc/kubernetes/manifests/kube-scheduler.yaml
```

The command prints nothing. The kubelet watches `/etc/kubernetes/manifests`, sees the changed file and restarts kube-scheduler. In the live run, the new listener appeared after about 15 seconds. Wait until the pod is Ready:

```sh
kubectl -n kube-system wait --for=condition=Ready "pod/kube-scheduler-$node_name" --timeout=120s
```

```text
pod/kube-scheduler-astro-ats-033-lab-030-03-01-control-plane condition met
```

## Step 5: Check the result

Read the listeners and the process again, then test from the node and from `shuttle`:

```sh
podman exec "$node_name" ss -tlnp | grep -E ':(10257|10259) '
podman exec "$node_name" pgrep -a kube-scheduler
podman exec "$node_name" curl -sk https://127.0.0.1:10259/healthz
kubectl -n starfleet-033-030-03-01 exec shuttle -- wget -q -T 3 -O- "https://$NODE_IP:10259/healthz"
```

```text
LISTEN 0      4096       127.0.0.1:10257      0.0.0.0:*    users:(("kube-controller",pid=563,fd=4))
LISTEN 0      4096       127.0.0.1:10259      0.0.0.0:*    users:(("kube-scheduler",pid=1896,fd=4))
1896 kube-scheduler --authentication-kubeconfig=/etc/kubernetes/scheduler.conf --authorization-kubeconfig=/etc/kubernetes/scheduler.conf --bind-address=127.0.0.1 --feature-gates=KubeletInUserNamespace=true --kubeconfig=/etc/kubernetes/scheduler.conf --leader-elect=true
ok
wget: can't connect to remote host (10.89.0.139): Connection refused
command terminated with exit code 1
```

kube-scheduler now runs as a new process (pid 1896) with `--bind-address=127.0.0.1`. The local health check still answers `ok`. The node refuses the connection from `shuttle`, because no process listens on port 10259 on the node address any more.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-030-03-01`.

## Common pitfalls

> [!WARNING]
> - **Editing the mirror pod.** `kubectl edit` on `kube-scheduler-<node>` in `kube-system` does not change the static pod. Edit the file in `/etc/kubernetes/manifests`.
> - **Leaving a backup copy in the manifest folder.** The kubelet starts every manifest file in that folder. Put backups somewhere else.
> - **Testing too early.** The kubelet needs a few seconds to restart the pod. Wait for Ready before you test.
> - **Testing only from the node.** A local request works with either bind address. Test from another node to prove the port is closed.
