---
exam_objectives:
- Minimize external access to the network
---
# Bind The Scheduler To Loopback Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-030-03-01
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-lab-030-03-01
```

You are logged in as the `student` user. Node files and processes belong to root, so the node commands below use `sudo`.

## Step 1: Read the listeners

The tool `ss` lists the sockets of a host. With `-tlnp` it shows the listening TCP sockets, with numeric addresses and the owning process. Read the listeners of kube-controller-manager (port 10257) and kube-scheduler (port 10259):

```sh
sudo ss -tlnp | grep -E ':(10257|10259) '
```

```text
LISTEN 0      4096       127.0.0.1:10257      0.0.0.0:*    users:(("kube-controller",pid=1662,fd=4))
LISTEN 0      4096               *:10259            *:*    users:(("kube-scheduler",pid=2686,fd=4))
```

kube-controller-manager listens on `127.0.0.1` only. kube-scheduler listens on `*`, which means every address of the node. Your process numbers can differ.

## Step 2: Find the flag

kube-scheduler is a static pod, so the kubelet on the node starts it from a manifest file. Read the bind address in that file and on the running process:

```sh
sudo grep -- --bind-address /etc/kubernetes/manifests/kube-scheduler.yaml
pgrep -a kube-scheduler
```

```text
    - --bind-address=0.0.0.0
2686 kube-scheduler --authentication-kubeconfig=/etc/kubernetes/scheduler.conf --authorization-kubeconfig=/etc/kubernetes/scheduler.conf --bind-address=0.0.0.0 --kubeconfig=/etc/kubernetes/scheduler.conf --leader-elect=true
```

Both show `--bind-address=0.0.0.0`. The manifest is the place to fix it: a change made with `kubectl edit` on the mirror pod in `kube-system` does not reach the kubelet.

## Step 3: Prove that the port is open to pods

Read the node address in the `INTERNAL-IP` column, then send a request from `shuttle` to that address:

```sh
kubectl get nodes -o wide
kubectl -n starfleet-033-030-03-01 exec shuttle -- wget -q -T 3 -O- https://10.0.2.15:10259/healthz
```

```text
NAME                          STATUS   ROLES           AGE   VERSION    INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
astro-ats-033-lab-030-03-01   Ready    control-plane   54s   v1.35.10   10.0.2.15     <none>        Ubuntu 24.04.5 LTS   6.8.0-149-generic   containerd://2.2.1
wget: note: TLS certificate validation not implemented
ok
```

The node address is `10.0.2.15`. If yours differs, use your address in the `wget` command. The health endpoint answers a pod that comes from the pod network. busybox `wget` does not check the certificate, so the `note` line is not an error.

## Step 4: Fix the manifest

Change the flag in the manifest. `sed -i` edits the file in place, and `sudo` is needed because root owns the file:

```sh
sudo sed -i 's/--bind-address=0.0.0.0/--bind-address=127.0.0.1/' /etc/kubernetes/manifests/kube-scheduler.yaml
```

The command prints nothing. The kubelet watches `/etc/kubernetes/manifests`, sees the changed file and restarts kube-scheduler. Wait about 20 seconds, then wait until the pod is Ready. The pod name ends with the node name:

```sh
kubectl -n kube-system wait --for=condition=Ready pod/kube-scheduler-astro-ats-033-lab-030-03-01 --timeout=120s
```

```text
pod/kube-scheduler-astro-ats-033-lab-030-03-01 condition met
```

## Step 5: Check the result

Read the listeners and the process again, then test from the node and from `shuttle`:

```sh
sudo ss -tlnp | grep -E ':(10257|10259) '
pgrep -a kube-scheduler
curl -sk https://127.0.0.1:10259/healthz; echo
kubectl -n starfleet-033-030-03-01 exec shuttle -- wget -q -T 3 -O- https://10.0.2.15:10259/healthz
```

```text
LISTEN 0      4096       127.0.0.1:10257      0.0.0.0:*    users:(("kube-controller",pid=1662,fd=4))
LISTEN 0      4096       127.0.0.1:10259      0.0.0.0:*    users:(("kube-scheduler",pid=3063,fd=4))
3063 kube-scheduler --authentication-kubeconfig=/etc/kubernetes/scheduler.conf --authorization-kubeconfig=/etc/kubernetes/scheduler.conf --bind-address=127.0.0.1 --kubeconfig=/etc/kubernetes/scheduler.conf --leader-elect=true
ok
wget: can't connect to remote host (10.0.2.15): Connection refused
command terminated with exit code 1
```

kube-scheduler now runs as a new process (pid 3063) with `--bind-address=127.0.0.1`. The local health check still answers `ok`. The node refuses the connection from `shuttle`, because no process listens on port 10259 on the node address any more.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-030-03-01`.

## Common pitfalls

> [!WARNING]
> - **Editing the mirror pod.** `kubectl edit` on `kube-scheduler-<node>` in `kube-system` does not change the static pod. Edit the file in `/etc/kubernetes/manifests`.
> - **Leaving a backup copy in the manifest folder.** The kubelet starts every manifest file in that folder. Put backups somewhere else.
> - **Testing too early.** The kubelet needs a few seconds to restart the pod. Wait for Ready before you test.
> - **Testing only from the node.** A local request works with either bind address. Test from a pod or another host to prove the port is closed.
