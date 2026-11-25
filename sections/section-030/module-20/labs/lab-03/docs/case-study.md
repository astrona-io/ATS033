---
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

The namespace `starfleet-033-030-02-03` runs the Deployment `probe`, the client pod `shuttle` and two Services for `probe`. The NodePort Service `probe-public` on node port 30081 is the approved entry. The Service `probe-legacy` is of type `ClusterIP`, but it also lists `203.0.113.10` in `externalIPs`. kube-proxy on every node then forwards traffic sent to that address on port 80 to the `probe` pods.

The namespace `outpost-033-030-02-03` holds two more entries. The Service `beacon-debug` is of type `NodePort` on node port 30090 and exposes the pod `beacon`. The pod `relay` uses the host network of the worker node and runs a Python web server on port 18080, which lists the files of the container.

A short audit with `kubectl get services -A` and `kubectl get pods -A --field-selector spec.hostNetwork=true` finds all three entries.
