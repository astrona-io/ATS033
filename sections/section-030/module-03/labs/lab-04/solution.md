---
exam_objectives:
- Minimize external access to the network
---
# Restrict The etcd Data Directory Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-030-03-04
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-lab-030-03-04
```

You are logged in as the `student` user. Node files belong to root, so the node commands below use `sudo`.

## Step 1: Find the data directory

etcd is the key-value store that holds every Kubernetes object. It runs as a static pod, which is a pod that the kubelet starts from a manifest file in `/etc/kubernetes/manifests`. The `--data-dir` flag in that manifest names the directory where etcd keeps its database files:

```sh
sudo grep -- --data-dir /etc/kubernetes/manifests/etcd.yaml
```

```text
    - --data-dir=/var/lib/etcd
```

## Step 2: Read the mode

`stat -c '%a %U %G %n'` prints the mode in numbers, the owner, the group and the name. `ls -ld` shows the same mode as letters:

```sh
sudo stat -c '%a %U %G %n' /var/lib/etcd
sudo ls -ld /var/lib/etcd /var/lib/etcd/member
```

```text
755 root root /var/lib/etcd
drwxr-xr-x 3 root root 4096 Nov 18 08:48 /var/lib/etcd
drwx------ 4 root root 4096 Nov 18 08:48 /var/lib/etcd/member
```

Mode `755` (`rwxr-xr-x`) lets every user on the node list and enter the directory. The subdirectory `member` already has `700`, but a scan reports the top directory, and the CIS (Center for Internet Security) Kubernetes Benchmark asks for `700` on the data directory itself.

## Step 3: Change the mode

`chmod 700` gives the owner read, write and enter rights, and removes all rights from the group and other users:

```sh
sudo chmod 700 /var/lib/etcd
```

The command prints nothing. etcd runs as `root`, the owner of the directory, so it keeps full access and does not need a restart.

## Step 4: Check the result

Read the mode again, ask etcd for its health with the API server's etcd client certificate, and check that the API server is ready:

```sh
sudo stat -c '%a %U %G %n' /var/lib/etcd
sudo ls -ld /var/lib/etcd /var/lib/etcd/member
sudo curl -s --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/apiserver-etcd-client.crt --key /etc/kubernetes/pki/apiserver-etcd-client.key https://127.0.0.1:2379/health
kubectl get --raw /readyz
```

```text
700 root root /var/lib/etcd
drwx------ 3 root root 4096 Nov 18 08:48 /var/lib/etcd
drwx------ 4 root root 4096 Nov 18 08:48 /var/lib/etcd/member
{"health":"true","reason":""}
ok
```

The directory now has mode `700` and owner `root:root`. etcd reports `"health":"true"`, and the API server answers `ok` on `/readyz`, so it can still read and write through etcd. The `curl` command needs `sudo` because only root can read the certificate files.

After recording your result, leave the VM with `exit` and remove the lab with `astrona destroy ats-033-lab-030-03-04`.

## Common pitfalls

> [!WARNING]
> - **Changing the owner.** etcd in a kubeadm cluster runs as `root`. A `chown` to another user can stop etcd from opening its files. Keep `root:root`.
> - **Changing the wrong path.** Read `--data-dir` from the manifest. A cluster can keep etcd data somewhere other than `/var/lib/etcd`.
> - **Using `chmod -R` with a wrong mode.** A recursive change with a mode such as `600` removes the enter right from subdirectories, and etcd fails. `chmod 700` on the top directory is enough.
> - **Calling etcd without a client certificate.** etcd requires a client certificate on port 2379. Use the API server's `apiserver-etcd-client` certificate for the health check.
