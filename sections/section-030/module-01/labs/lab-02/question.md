---
exam_objectives:
- Minimize external access to the network
---
# Question

Solve this question on: `terminal`

A metrics agent on the node must stay reachable for processes on the node only. The pod `node-metrics-server` in the namespace `starfleet-033-030-01-02` runs Python's web server on port 19091 in the network of the node (`hostNetwork: true`). It listens on every address, and the team wants to keep that bind address. Right now every pod can reach it. The pod `shuttle` in the same namespace is a normal pod with its own pod network address, and it is the test client.

The lab VM (virtual machine) runs a one-node Kubernetes cluster built with kubeadm. The node is the control plane and also runs the pods. Open a shell on the lab VM and check that `kubectl`, the Kubernetes command-line tool, uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-030-01-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-033-lab-030-01-02`. You are logged in as the `student` user, which has a kubeconfig file for the cluster. A kubeconfig file tells `kubectl` which cluster to use and which credentials to send. `ufw` (Uncomplicated Firewall) is installed on the node but not active. Firewall commands need `sudo`. They change only the lab VM, not your own computer.

Allow about 10 minutes for the tasks. Cluster startup adds time.

## Tasks

1. Add a `ufw` rule on the node that denies incoming TCP traffic to port 19091.
2. Turn on `ufw`.
3. Confirm that a request from `shuttle` to the node's InternalIP on port 19091 now fails, and that a request on the node itself to the same address and port still returns the page.

## Constraints

- Keep `node-metrics-server` running and listening on port 19091. Do not change its bind address.
- Do not change the default policies of `ufw`. They allow incoming and routed traffic, so SSH, the API server and pod traffic keep working when `ufw` is on.
- Do not add a NetworkPolicy. The task is about the host firewall.

## How the answer is checked

The grader runs two checks. First, `ufw status` on the node shows `Status: active` and a `DENY` or `REJECT` rule for `19091/tcp`. Second, a request from `shuttle` to the node's InternalIP on port 19091 fails with a timeout or `Connection refused`. Both checks also need `ss` on the node to show a listener on port 19091 that is not bound to `127.0.0.1`, and a request on the node to its own InternalIP on port 19091 to return the page with the text `Directory listing for /`.

Hint: `ufw enable` asks a yes or no question, because a firewall can cut SSH connections. Answer `y`, or add `--force` to skip the question.
