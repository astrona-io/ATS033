# Minimize External Access To The Network

Picture a management service on a node that listens on every network interface. The administrators only ever reach it from one protected network. Every other network the node is connected to can still reach it, even though nobody needs that.

Every open port is a way into the node or the cluster. A port can be closed in more than one place: the program can listen only on the address it needs, a host firewall can drop traffic, and the program can check who is calling. In this section, you learn how to find what is open, how to close what nobody needs, and how to protect the ports the cluster cannot do without.

## What you will learn

The section moves from the node to the cluster and then to the control plane:

- **Minimize External Access To The Network.** Listeners and bind addresses, host firewalls with `iptables` and `ufw`, NetworkPolicy for Pod traffic, and a first look at NodePorts, control-plane ports and API access.
- **Limit Service Exposure Outside The Cluster.** What each Service type opens, how to narrow NodePorts and load balancers, and how to find Ingress rules and other exposed Services.
- **Restrict Access To The API Server And Control-Plane Ports.** The ports the control plane listens on, authentication and authorization on the API server and the kubelet, and who may talk to etcd.

## How this section works

Each module has its own playground. The first two modules work with Pods and Services, so their playground is a private `kind` cluster. The third module works on the control-plane files of a node, so its playground is a virtual machine (VM) that runs Ubuntu and a one-node Kubernetes cluster built with kubeadm. You log in to it with `astrona ssh`. Start the playground from the first page of the module and keep it running while you read.

When a page teaches a skill you can be graded on, a lab comes right after it. A lab gives you a short task in a fresh environment and checks your result. Each module ends with a summary and a short knowledge check.

## By the end of this section

You will be able to:

- list the listeners of a node and the address each one is bound to;
- explain the difference between a bind address, a firewall rule and a check of the caller;
- write host firewall rules and NetworkPolicies without breaking the traffic the cluster needs;
- explain what each Service type opens, and narrow NodePorts, load balancers and Ingress rules;
- check how the API server and the kubelet authenticate and authorize requests;
- limit client access to etcd to the components that need it.
