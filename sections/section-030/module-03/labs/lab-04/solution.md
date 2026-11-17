---
exam_objectives:
- Minimize external access to the network
---
# Restrict The etcd Data Directory Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-03-04)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-03-04" || exit 1
node_name="astro-ats-033-lab-030-03-04-control-plane"
worker_name="astro-ats-033-lab-030-03-04-worker"
```

Keep this connection selected.

## Step 1: Find the data directory

etcd is the key-value store that holds every Kubernetes object. It runs as a static pod, which is a pod that the kubelet starts from a manifest file in `/etc/kubernetes/manifests`. The `--data-dir` flag in that manifest names the directory where etcd keeps its database files:

```sh
podman exec "$node_name" grep -- --data-dir /etc/kubernetes/manifests/etcd.yaml
```

```text
    - --data-dir=/var/lib/etcd
```

## Step 2: Read the mode

`stat -c '%a %U %G %n'` prints the mode in numbers, the owner, the group and the name. `ls -ld` shows the same mode as letters:

```sh
podman exec "$node_name" stat -c '%a %U %G %n' /var/lib/etcd
podman exec "$node_name" ls -ld /var/lib/etcd /var/lib/etcd/member
```

```text
755 root root /var/lib/etcd
drwxr-xr-x. 3 root root 20 Nov 17 22:22 /var/lib/etcd
drwx------. 4 root root 29 Nov 17 22:22 /var/lib/etcd/member
```

Mode `755` (`rwxr-xr-x`) lets every user on the node list and enter the directory. The subdirectory `member` already has `700`, but a scan reports the top directory, and the CIS (Center for Internet Security) Kubernetes Benchmark asks for `700` on the data directory itself.

## Step 3: Change the mode

`chmod 700` gives the owner read, write and enter rights, and removes all rights from the group and other users:

```sh
podman exec "$node_name" chmod 700 /var/lib/etcd
```

The command prints nothing. etcd runs as `root`, the owner of the directory, so it keeps full access and does not need a restart.

## Step 4: Check the result

Then check the result. Read the mode again, ask etcd for its health with the API server's etcd client certificate, and check that the API server is ready:

```sh
podman exec "$node_name" stat -c '%a %U %G %n' /var/lib/etcd
podman exec "$node_name" ls -ld /var/lib/etcd /var/lib/etcd/member
podman exec "$node_name" curl -s --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/apiserver-etcd-client.crt --key /etc/kubernetes/pki/apiserver-etcd-client.key https://127.0.0.1:2379/health
kubectl get --raw /readyz
```

```text
700 root root /var/lib/etcd
drwx------. 3 root root 20 Nov 17 22:22 /var/lib/etcd
drwx------. 4 root root 29 Nov 17 22:22 /var/lib/etcd/member
{"health":"true","reason":""}
ok
```

The directory now has mode `700` and owner `root:root`. etcd reports `"health":"true"`, and the API server answers `ok` on `/readyz`, so it can still read and write through etcd.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-030-03-04`.

## Common pitfalls

> [!WARNING]
> - **Changing the owner.** etcd in a kubeadm cluster runs as `root`. A `chown` to another user can stop etcd from opening its files. Keep `root:root`.
> - **Changing the wrong path.** Read `--data-dir` from the manifest. A cluster can keep etcd data somewhere other than `/var/lib/etcd`.
> - **Using `chmod -R` with a wrong mode.** A recursive change with a mode such as `600` removes the enter right from subdirectories, and etcd fails. `chmod 700` on the top directory is enough.
> - **Calling etcd without a client certificate.** etcd requires a client certificate on port 2379. Use the API server's `apiserver-etcd-client` certificate for the health check.
