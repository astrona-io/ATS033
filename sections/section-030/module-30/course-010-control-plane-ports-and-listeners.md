# Control-Plane Ports And Listeners

A firewall rule is only as good as the list of ports behind it. That list comes from what the components really listen on. If you do not know which process opens which port, on which address, you cannot write a rule that closes the right things.

This page names the ports of a Kubernetes control-plane node and says who should connect to each one. Then you read the real listeners of a node with `ss`. The goal is to turn a vague sentence like "the API server port is open" into a precise statement about address, port and caller.

## The ports and their callers

A kubeadm cluster, such as the one in the playground, runs the control-plane components as **static pods**. A static pod is a pod that the kubelet starts from a manifest file in `/etc/kubernetes/manifests`, without the API server. Each component opens its own ports.

| Port | Component | Callers that need it |
| --- | --- | --- |
| 6443 | kube-apiserver | Users, nodes, controllers, from known networks |
| 10250 | kubelet API (on every node) | The API server and monitoring |
| 2379 | etcd client port | The API servers only |
| 2380 | etcd peer port | The other etcd members only |
| 10257 | kube-controller-manager | Health checks and metrics, from the node |
| 10259 | kube-scheduler | Health checks and metrics, from the node |

Each component also has a default bind address. The bind address is the network address on which a component waits for connections. The defaults differ by component:

- The API server listens on all addresses (`--bind-address` defaults to `0.0.0.0`), because users and nodes connect from other machines.
- The kubelet also listens on all addresses.
- In a kubeadm cluster, kubeadm starts the controller manager and the scheduler with `--bind-address=127.0.0.1`. Their ports accept connections only from the node itself.
- etcd listens for clients (port 2379) on the loopback address and on the node address. It listens for peers (port 2380) on the node address.

![Diagram: a user or node connects to kube-apiserver on port 6443, kube-controller-manager also connects to port 6443, and only kube-apiserver connects to etcd on port 2379 and to the kubelet on port 10250](images/expected-port-paths.svg)

The drawing shows the expected paths. Only the API server connects to etcd, and only the API server connects to the kubelet, for logs and exec. Any other path to those ports is a finding.

## Who does the work

So far you know which port belongs to which component. Two separate layers decide who can actually reach each port.

The first layer is the bind address, set in the flags of the component. It decides on which network interface the component listens. The second layer is the network filter, such as a host firewall or a cloud security group. It decides which source addresses may reach a listener that is open.

![Diagram: a remote caller is stopped by the firewall or by a loopback bind address, a caller from an allowed network passes the firewall and reaches a listener on all addresses](images/bind-address-and-firewall.svg)

The drawing shows the two layers one after the other. A well-run cluster uses both, because a changed flag or a deleted firewall rule alone would reopen the port.

## Read the listeners of the control-plane node

Now look at the real node. Open a shell on the playground VM (virtual machine) and check that `kubectl` uses the playground cluster:

<!-- astrona:playground:renew -->

```sh
astrona ssh astro-ats-033-playground-030-03
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-playground-030-03
```

You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. The VM is the only node of the cluster, so the commands below read the real node. Process details and node files belong to root, so node commands run with `sudo`.

Now list the listeners of the node:

```sh
sudo ss -tlnp
```

```text
State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess
LISTEN 0      4096       127.0.0.1:2381       0.0.0.0:*    users:(("etcd",pid=1658,fd=11))
LISTEN 0      4096       127.0.0.1:2379       0.0.0.0:*    users:(("etcd",pid=1658,fd=7))
LISTEN 0      4096       127.0.0.1:10257      0.0.0.0:*    users:(("kube-controller",pid=1614,fd=4))
LISTEN 0      4096       127.0.0.1:10259      0.0.0.0:*    users:(("kube-scheduler",pid=1634,fd=4))
LISTEN 0      4096       127.0.0.1:10248      0.0.0.0:*    users:(("kubelet",pid=2785,fd=23))
LISTEN 0      4096       127.0.0.1:10249      0.0.0.0:*    users:(("kube-proxy",pid=1889,fd=15))
LISTEN 0      4096   127.0.0.53%lo:53         0.0.0.0:*    users:(("systemd-resolve",pid=473,fd=15))
LISTEN 0      4096       127.0.0.1:38393      0.0.0.0:*    users:(("containerd",pid=808,fd=3))
LISTEN 0      4096      127.0.0.54:53         0.0.0.0:*    users:(("systemd-resolve",pid=473,fd=17))
LISTEN 0      4096         0.0.0.0:22         0.0.0.0:*    users:(("sshd",pid=1041,fd=3),("systemd",pid=1,fd=144))
LISTEN 0      4096       10.0.2.15:2380       0.0.0.0:*    users:(("etcd",pid=1658,fd=3))
LISTEN 0      4096       10.0.2.15:2379       0.0.0.0:*    users:(("etcd",pid=1658,fd=6))
LISTEN 0      4096               *:10250            *:*    users:(("kubelet",pid=2785,fd=20))
LISTEN 0      4096            [::]:22            [::]:*    users:(("sshd",pid=1041,fd=4),("systemd",pid=1,fd=146))
LISTEN 0      4096               *:10256            *:*    users:(("kube-proxy",pid=1889,fd=10))
LISTEN 0      4096               *:6443             *:*    users:(("kube-apiserver",pid=1651,fd=4))
```

The command `ss -tlnp` lists sockets, and its options choose what to show:

- `-t` shows TCP sockets.
- `-l` shows only sockets in the listening state.
- `-n` prints numbers instead of names.
- `-p` shows the process of each socket.

Without `sudo`, `ss` cannot show the process of a socket that belongs to root. The column `Local Address:Port` shows the bind address. A line with `127.0.0.1:10257` accepts connections from the node only. A line with `*:6443` or `0.0.0.0:22` accepts connections on every interface.

The node address in this playground is `10.0.2.15`, and your process numbers can differ. The full list is long, so filter it down to the six ports of the table:

```sh
sudo ss -tlnp | grep -E ':(6443|10250|2379|2380|10257|10259) '
```

```text
LISTEN 0      4096       127.0.0.1:2379       0.0.0.0:*    users:(("etcd",pid=1658,fd=7))
LISTEN 0      4096       127.0.0.1:10257      0.0.0.0:*    users:(("kube-controller",pid=1614,fd=4))
LISTEN 0      4096       127.0.0.1:10259      0.0.0.0:*    users:(("kube-scheduler",pid=1634,fd=4))
LISTEN 0      4096       10.0.2.15:2380       0.0.0.0:*    users:(("etcd",pid=1658,fd=3))
LISTEN 0      4096       10.0.2.15:2379       0.0.0.0:*    users:(("etcd",pid=1658,fd=6))
LISTEN 0      4096               *:10250            *:*    users:(("kubelet",pid=2785,fd=20))
LISTEN 0      4096               *:6443             *:*    users:(("kube-apiserver",pid=1651,fd=4))
```

The API server and the kubelet use the wildcard address `*`. The controller manager and the scheduler use the loopback address. etcd has two client listeners, one on loopback and one on the node address, and its peer listener is on the node address.

If the scheduler showed a wildcard address instead, that would be a finding. Its port gives metrics to any caller that reaches it.

## Confirm the setting in the manifest

The listener shows the result, and the manifest shows the cause. Read the bind address flags of the two components that should stay local. The manifests belong to root, so `grep` needs `sudo`:

```sh
sudo grep -H 'bind-address' /etc/kubernetes/manifests/kube-controller-manager.yaml /etc/kubernetes/manifests/kube-scheduler.yaml
```

```text
/etc/kubernetes/manifests/kube-controller-manager.yaml:    - --bind-address=127.0.0.1
/etc/kubernetes/manifests/kube-scheduler.yaml:    - --bind-address=127.0.0.1
```

Each file has the line `--bind-address=127.0.0.1`. When you find a wide listener, correct the flag in the manifest. The kubelet watches the manifests directory and restarts the static pod by itself.

## When a port is wider than its job

Some ports must accept remote connections, such as 6443. For those, the bind address cannot be the control, so the network filter takes over. The standard answer is a host firewall rule that accepts port 6443 from the networks of administrators and nodes and drops the rest. In a cloud, a security group does the same job.

The other ports get their own rules:

- Ports 2379 and 2380 get a rule that allows only the control-plane nodes.
- Port 10250 allows the control-plane nodes and the monitoring system.

You have now mapped each port to a component, a caller and a bind address. You also know that the bind address and the network filter are two separate layers. The open question is what the API server does with a caller that does reach port 6443.

## Common pitfalls

> [!WARNING]
> - **Reading only the firewall.** A listener on `0.0.0.0` stays open to everything that a later firewall change allows. Check the bind address as well.
> - **Treating loopback as protection against local pods.** A pod with `hostNetwork: true` shares the loopback address of the node.
> - **Editing a static pod manifest in place without a copy.** A typo makes the component fail to start. Keep a copy outside the manifests directory first.
> - **Checking IPv4 only.** A component can also listen on `::`. Read every line of the `ss` output.
