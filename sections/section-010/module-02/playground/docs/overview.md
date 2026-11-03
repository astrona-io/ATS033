---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Guided Practice: Harden SSH Access And Unused Accounts

Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-010-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-010-02" || exit 1
node_name="astro-ats-033-playground-010-02-control-plane"
worker_name="astro-ats-033-playground-010-02-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

Read the effective SSH settings before you change anything. The shell expands the file names in sorted order, which is the order the daemon reads them, because the first line of the main file includes the drop-in directory.

```sh
podman exec "$node_name" sh -c 'cat /etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config'
podman exec "$node_name" getent passwd opsadmin olduser
```

The drop-in file comes first and sets `PasswordAuthentication yes`. The daemon uses the first value it reads for a setting, so the later `PasswordAuthentication no` in the main file has no effect. This is the fault to repair, together with the root login, the missing `AllowUsers` line and the shell of `olduser`.

Change only the control-plane node of this environment.

1. Set `PermitRootLogin` to `no`.
2. Make the first `PasswordAuthentication` value that sshd reads `no`. Keep `PubkeyAuthentication` set to `yes`.
3. Allow only the account `opsadmin` with an `AllowUsers` line.
4. Give `olduser` the login shell `/usr/sbin/nologin` and lock its password. Do not delete the account and do not change `opsadmin`.
5. Create the ConfigMap `node-access-review` in the `starfleet` namespace with the data `ssh: key-only`, `account: olduser` and `result: hardened`.

The `kubelet` and `containerd` services must stay active and the API readiness endpoint must answer.

Save this as `harden-ssh.py`:

```python
import subprocess
CONTEXT="kind-astro-ats-033-playground-010-02"
NODE="astro-ats-033-playground-010-02-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-033-playground-010-02', 'Refusing an unrelated node container'
def node(*args):return run('podman','exec',NODE,*args)

node('sed','-i','s/^PermitRootLogin .*/PermitRootLogin no/','/etc/ssh/sshd_config')
node('sed','-i','s/^PasswordAuthentication .*/PasswordAuthentication no/','/etc/ssh/sshd_config.d/50-cloud-init.conf')
if 'AllowUsers' not in node('cat','/etc/ssh/sshd_config'):
    node('sh','-c',"printf 'AllowUsers opsadmin\\n' >> /etc/ssh/sshd_config")
node('usermod','--shell','/usr/sbin/nologin','--lock','olduser')
```

Save this as `configmap-node-access-review.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: node-access-review
  namespace: starfleet
data:
  ssh: key-only
  account: olduser
  result: hardened
```

Apply the scoped correction:

```sh
python3 harden-ssh.py
kubectl apply -f configmap-node-access-review.yaml
```

## Verify The Result

Read the settings again and check the accounts and the cluster. A node that still answers the readiness endpoint shows that the change did not touch Kubernetes.

```sh
podman exec "$node_name" sh -c 'cat /etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config'
podman exec "$node_name" getent passwd olduser
podman exec "$node_name" passwd -S olduser
kubectl get --raw=/readyz
```

The first value of each setting must now be the required one, `olduser` must show `/usr/sbin/nologin` and the status letter `L`, and the readiness endpoint must answer `ok`.

## Common pitfalls

> [!WARNING]
> - Edit the file that holds the first value of a setting. A correct line later in the main file does not override an earlier drop-in.
> - Do not remove `PubkeyAuthentication yes` while you turn passwords off. Key logins are the access path that remains.
> - Do not delete `olduser` or change `opsadmin`. The task asks for a login restriction, not for account removal.
> - Confirm the private context and the node container name before you change a file.
