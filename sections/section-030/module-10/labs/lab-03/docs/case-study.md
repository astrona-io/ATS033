---
exam_objectives:
- Minimize external access to the network
---
# Starting Environment

The namespace `starfleet-033-030-01-03` runs the Deployment `probe` with two replicas behind the ClusterIP Service `probe`, the pod `beacon` and the client pod `shuttle`. The namespace `outpost-033-030-01-03` runs the client pod `drifter`. Both `probe` and `beacon` answer HTTP requests on port 8080 with a line such as `version=v1 host=<pod name>`.

There is no NetworkPolicy in the cluster, so every pod can reach every other pod. The bootstrap checked that the network plugin of the cluster, kindnet, enforces NetworkPolicy: it applied a temporary deny policy to `beacon`, saw a request from `drifter` fail, removed the policy and saw the request work again.
