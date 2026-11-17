---
exam_objectives:
- Using least-privilege identity and access management
---
# Starting Environment

The cluster has the namespace `starfleet-033-020-03-02` with the ServiceAccount `relay` and the Deployment `relay`, one replica. The Pod runs as `relay` and receives the default token at `/var/run/secrets/kubernetes.io/serviceaccount/token`.

That token has the API server as its audience and lives about one hour. No other token volume exists yet.
