---
exam_objectives:
- Minimize external access to the network
---
# Block A Host Port With ufw Solution

Open a shell on the lab VM (virtual machine) and check that `kubectl` uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-030-01-02
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-lab-030-01-02
```

You are logged in as the `student` user. The lab VM is the only node of the cluster, so the firewall of the VM is the firewall of the node. `ufw` commands need `sudo`.

## Step 1: Read the addresses and test the current access

The test request needs the InternalIP of the node. Read it and look at where the pods run:

```sh
kubectl get nodes -o wide
kubectl -n starfleet-033-030-01-02 get pods -o wide
```

```text
NAME                          STATUS   ROLES           AGE   VERSION    INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
astro-ats-033-lab-030-01-02   Ready    control-plane   57s   v1.35.10   10.0.2.15     <none>        Ubuntu 24.04.5 LTS   6.8.0-149-generic   containerd://2.2.1
NAME                  READY   STATUS    RESTARTS   AGE   IP           NODE                          NOMINATED NODE   READINESS GATES
node-metrics-server   1/1     Running   0          9s    10.0.2.15    astro-ats-033-lab-030-01-02   <none>           <none>
shuttle               1/1     Running   0          9s    10.244.0.4   astro-ats-033-lab-030-01-02   <none>           <none>
```

`node-metrics-server` shows the node address `10.0.2.15` as its pod IP, because it uses the network of the node. `shuttle` has the pod IP `10.244.0.4` from the pod network. Save the node address in a variable, then check the listener, the firewall and the request from `shuttle`:

```sh
NODE_IP=10.0.2.15
sudo ss -tlnp 'sport = :19091'
sudo ufw status verbose
kubectl -n starfleet-033-030-01-02 exec shuttle -- wget -q -T 3 -O /dev/null "http://$NODE_IP:19091/"
echo "rc=$?"
```

```text
State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess
LISTEN 0      5            0.0.0.0:19091      0.0.0.0:*    users:(("python",pid=2556,fd=3))
Status: inactive
rc=0
```

The server listens on the wildcard address `0.0.0.0`, so it accepts connections on every address of the node. `ufw` is not active, and the request from `shuttle` worked: `wget` printed nothing and ended with exit code 0.

## Step 2: Add the deny rule and turn on ufw

`ufw` stores its own rules and writes them into netfilter, the packet filter of the Linux kernel, when it is active. A rule added while `ufw` is inactive is saved and takes effect when you turn `ufw` on. The default policies decide what happens to traffic that no rule matches. In this lab they allow incoming and routed traffic, so the only change is the new rule:

```sh
sudo ufw deny 19091/tcp
sudo ufw --force enable
sudo ufw status verbose
```

```text
Rules updated
Rules updated (v6)
Firewall is active and enabled on system startup
Status: active
Logging: on (low)
Default: allow (incoming), allow (outgoing), allow (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
19091/tcp                  DENY IN     Anywhere                  
19091/tcp (v6)             DENY IN     Anywhere (v6)
```

`ufw deny 19091/tcp` added one rule for IPv4 and one for IPv6. `ufw enable` normally asks a yes or no question, because a firewall can cut the SSH connection you work in. `--force` skips the question. `ufw` also turns itself on at the next boot, so this rule survives a restart of the node.

## Step 3: Check the result

Send the request from `shuttle` again. It is expected to fail. Then send a request on the node to its own address, and check that the server still listens and the node is still `Ready`:

```sh
kubectl -n starfleet-033-030-01-02 exec shuttle -- wget -q -T 3 -O /dev/null "http://$NODE_IP:19091/"
curl -s -o /dev/null -w '%{http_code}\n' "http://$NODE_IP:19091/"
sudo ss -tlnp 'sport = :19091'
kubectl get nodes
```

```text
wget: download timed out
command terminated with exit code 1
200
State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess
LISTEN 0      5            0.0.0.0:19091      0.0.0.0:*    users:(("python",pid=2556,fd=3))
NAME                          STATUS   ROLES           AGE   VERSION
astro-ats-033-lab-030-01-02   Ready    control-plane   72s   v1.35.10
```

The request from `shuttle` arrives at the node from the pod network. It matches the deny rule, and the kernel drops the packet without an answer, so `wget` waits until its 3-second timeout. The request from the node to its own address travels over the loopback interface `lo`. `ufw` accepts all traffic on `lo` before it checks your rules, so that request gets status 200.

The listener has not changed: the firewall, not the server, decides who gets in. You can see the rule that `ufw` wrote into the kernel:

```sh
sudo iptables -L ufw-user-input -n
```

```text
Chain ufw-user-input (1 references)
target     prot opt source               destination         
DROP       6    --  0.0.0.0/0            0.0.0.0/0            tcp dpt:19091
```

The `DROP` target throws away TCP (protocol number 6) packets for port 19091. `ufw` keeps your rules in its own chains, such as `ufw-user-input`, so they do not mix with the `KUBE-*` chains that kube-proxy manages.

After recording your result, leave the VM with `exit` and remove the lab from your own computer with `astrona destroy ats-033-lab-030-01-02`.

## Common pitfalls

> [!WARNING]
> - **Setting `ufw default deny incoming` on a remote node.** Without an allow rule for SSH (port 22) and the API server (port 6443), the next `ufw enable` cuts your own connection and the cluster traffic. Add the allow rules before you change the default policy.
> - **Adding the rule and forgetting `ufw enable`.** An inactive `ufw` keeps the rule on disk, but nothing reaches the kernel. Check for `Status: active`.
> - **Testing only on the node.** A request on the node to its own address uses the loopback interface, which `ufw` always accepts. Test from a pod or another host, as the grader does.
