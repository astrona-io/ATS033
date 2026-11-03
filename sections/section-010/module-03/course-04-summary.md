---
draft: true
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Summary

A container's isolation comes from Linux namespaces and from the files of its image. The pod fields `hostNetwork`, `hostPID`, `hostIPC`, `hostPath` and `privileged` switch parts of that isolation off. The kubelet and the container runtime carry out whatever the pod specification says, so only an admission check in the API server can refuse such a pod. A pod that shares the node's PID namespace sees the processes of the node, and a pod on the host network has the address of the node.

Pod Security Admission applies the `privileged`, `baseline` and `restricted` standards through namespace labels in the modes `enforce`, `warn` and `audit`. The `baseline` standard blocks host namespaces, `hostPath` volumes and privileged containers, and `restricted` adds non-root users, no privilege escalation, dropped capabilities and a seccomp profile. A server-side dry run of a label previews the effect. A Deployment passes admission even when its pods do not, so the error appears as a `FailedCreate` event on the ReplicaSet. The `enforce` mode checks new and updated pods and does not remove running ones.

The kubelet API must reject anonymous requests, use `Webhook` authorization and keep the read-only port off. A dedicated node needs two parts: a taint to repel other workloads, and a label with a node selector, together with a toleration, to send the sensitive workload. The prefix `node-restriction.kubernetes.io/` stops a compromised node from labelling itself. A `NoSchedule` taint does not move pods that already run, and it blocks replacement pods that lack a toleration.

Key facts:

- Pod Security Admission checks pods, not Deployments.
- Fix the pod template before you add an `enforce` label.
- A toleration allows a pod on a tainted node; a node selector sends it there.
- The kubelet needs anonymous access off, `Webhook` authorization and no read-only port.

<!-- astrona:playground:destroy -->
