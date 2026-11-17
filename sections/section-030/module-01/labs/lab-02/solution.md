---
exam_objectives:
- Minimize external access to the network
---
# Allow A Node Port Only From The Worker With iptables Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-030-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-030-01-02" || exit 1
node_name="astro-ats-033-lab-030-01-02-control-plane"
worker_name="astro-ats-033-lab-030-01-02-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Step 1: Read the addresses and test the current access

The rules need the InternalIP of the worker node, and the test requests need the InternalIP of the control-plane node. Read both and look at where the pods run:

```sh
NODE_IP="$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
WORKER_IP="$(kubectl get node "$worker_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
echo "NODE_IP=$NODE_IP WORKER_IP=$WORKER_IP"
kubectl -n starfleet-033-030-01-02 get pods -o wide
```

The live run printed the output below. The `NOMINATED NODE` and `READINESS GATES` columns are cut here, and your addresses can differ:

```text
NODE_IP=10.89.0.74 WORKER_IP=10.89.0.73
NAME                  READY   STATUS    RESTARTS   AGE   IP           NODE
node-metrics-server   1/1     Running   0          6s    10.89.0.74   astro-ats-033-lab-030-01-02-control-plane
scout                 1/1     Running   0          6s    10.89.0.73   astro-ats-033-lab-030-01-02-worker
shuttle               1/1     Running   0          6s    10.244.0.5   astro-ats-033-lab-030-01-02-control-plane
```

`node-metrics-server` and `scout` show the node address as their pod IP, because both use the network of their node. `shuttle` has a pod IP from the pod network. Now send a request from each test pod:

```sh
kubectl -n starfleet-033-030-01-02 exec shuttle -- wget -q -T 3 -O /dev/null "http://$NODE_IP:19091/"
kubectl -n starfleet-033-030-01-02 exec scout -- wget -q -T 3 -O /dev/null "http://$NODE_IP:19091/"
```

Both commands print nothing and end with exit code 0, so both requests worked.

## Step 2: Read the INPUT chain

The `INPUT` chain of the `filter` table decides about packets that are addressed to the node itself. List it with rule numbers:

```sh
podman exec "$node_name" iptables --list INPUT --numeric --line-numbers
```

```text
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination         
1    KUBE-PROXY-FIREWALL  0    --  0.0.0.0/0            0.0.0.0/0            ctstate NEW /* kubernetes load balancer firewall */
2    KUBE-NODEPORTS  0    --  0.0.0.0/0            0.0.0.0/0            /* kubernetes health check service ports */
3    KUBE-EXTERNAL-SERVICES  0    --  0.0.0.0/0            0.0.0.0/0            ctstate NEW /* kubernetes externally-visible service portals */
4    KUBE-FIREWALL  0    --  0.0.0.0/0            0.0.0.0/0           
```

kube-proxy created the four `KUBE-*` rules. None of them matches port 19091, and the chain policy is `ACCEPT`, so the node accepts every packet for port 19091. Leave these rules as they are.

## Step 3: Add the accept and drop rules

`iptables` checks the rules of a chain from the top and stops at the first rule that matches. The accept rule for the worker must therefore come before the drop rule. `--append` adds each rule at the end of the chain, so run the two commands in this order:

```sh
podman exec "$node_name" iptables --append INPUT --protocol tcp --dport 19091 --source "$WORKER_IP" --jump ACCEPT
podman exec "$node_name" iptables --append INPUT --protocol tcp --dport 19091 --jump DROP
podman exec "$node_name" iptables --list INPUT --numeric --line-numbers
```

```text
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination         
1    KUBE-PROXY-FIREWALL  0    --  0.0.0.0/0            0.0.0.0/0            ctstate NEW /* kubernetes load balancer firewall */
2    KUBE-NODEPORTS  0    --  0.0.0.0/0            0.0.0.0/0            /* kubernetes health check service ports */
3    KUBE-EXTERNAL-SERVICES  0    --  0.0.0.0/0            0.0.0.0/0            ctstate NEW /* kubernetes externally-visible service portals */
4    KUBE-FIREWALL  0    --  0.0.0.0/0            0.0.0.0/0           
5    ACCEPT     6    --  10.89.0.73           0.0.0.0/0            tcp dpt:19091
6    DROP       6    --  0.0.0.0/0            0.0.0.0/0            tcp dpt:19091
```

Rule 5 accepts TCP (protocol number 6) to port 19091 from the worker address. Rule 6 drops every other TCP packet to port 19091. The `DROP` target throws the packet away without an answer, so the client waits until its own timeout.

## Step 4: Check the result

Send the same two requests again, and check that the server still listens:

```sh
kubectl -n starfleet-033-030-01-02 exec shuttle -- wget -q -T 3 -O /dev/null "http://$NODE_IP:19091/"
kubectl -n starfleet-033-030-01-02 exec scout -- wget -q -T 3 -O /dev/null "http://$NODE_IP:19091/"
podman exec "$node_name" ss -tlnp 'sport = :19091'
```

```text
wget: download timed out
command terminated with exit code 1
State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess
LISTEN 0      5            0.0.0.0:19091      0.0.0.0:*    users:(("python",pid=1758,fd=3))
```

The request from `shuttle` comes from its pod IP, matches rule 6 and times out. The request from `scout` comes from the worker address, matches rule 5 and works, so it prints nothing. The listener has not changed: the firewall rules, not the server, decide who gets in.

These rules live only in the memory of the node. A restart of the node removes them. On a real server you would save them with a tool such as `iptables-save` and restore them at boot, or use a firewall front end such as `ufw`. The kind node has no `ufw`, and the lab does not grade persistence.

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-030-01-02`.

## Common pitfalls

> [!WARNING]
> - **Drop rule before accept rule.** If the drop rule comes first, it matches the worker too, and `scout` also times out. Delete the rule with `iptables --delete INPUT <number>` and add the rules in the right order.
> - **Testing from a pod on the worker.** kindnet replaces the source address of pod traffic that leaves a node with the node address. A normal pod on the worker therefore reaches the control-plane node with the worker address and passes the accept rule.
> - **Testing only on the node.** A request on the node to its own address is also dropped by rule 6, because it does not come from the worker address. Test from the pods, as the grader does.
