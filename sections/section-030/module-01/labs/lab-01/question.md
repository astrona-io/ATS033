---
exam_objectives:
- Minimize external access to the network
---
# Question

Solve this question on: `terminal`

A node agent was deployed for local health checks, and a security scan of the node found it listening on all interfaces. The pod `node-local-server` in the namespace `starfleet-033-030-01-01` runs Python's web server on port 19090 in the network of the node (`hostNetwork: true`). Its command binds the server to `0.0.0.0`, so the pod `shuttle` in the same namespace can reach it at the node address. `shuttle` has its own pod network address, so its requests to the node address come from outside the node's network. Only processes on the node itself need this server.

The lab VM (virtual machine) runs a one-node Kubernetes cluster built with kubeadm. The node is the control plane and also runs the pods. Open a shell on the lab VM and check that `kubectl`, the Kubernetes command-line tool, uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-030-01-01
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-030-01-01`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. Commands that read the processes of the node, such as `ss -p`, need `sudo`. They change only the lab VM, not your own computer.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Find the listener of port 19090 on the node and confirm that it accepts connections on every address.
2. Change `node-local-server` so that the web server listens on `127.0.0.1:19090` only. Keep the pod name, the namespace, the host network and the node.
3. Confirm that a request on the node's loopback address returns status 200, and that a request from `shuttle` to the node's InternalIP on port 19090 fails with `Connection refused`.

## Constraints

- Fix the listener itself. Do not add a firewall rule or a NetworkPolicy.
- Keep `shuttle` and every other component of the cluster as they are.

## How the answer is checked

The grader runs two checks. First, `ss` on the node shows port 19090 on `127.0.0.1` and on no other address. Second, a request from `shuttle` to the node's InternalIP on port 19090 gets `Connection refused`. Both checks also need `node-local-server` to be `Ready` on the node and a request to `http://127.0.0.1:19090/` on the node to return 200.

Hint: the command of a running container cannot change. Replace the pod.
