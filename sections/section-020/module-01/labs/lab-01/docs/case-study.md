---
exam_objectives:
- Using least-privilege identity and access management
---
# Starting Environment

The cluster has one control-plane node and no application workloads. The node holds the file `/srv/flight-logs/telemetry.log`, owned by `root:root` with mode `644`, so every account on the node can read it.

The node also has two normal accounts, `navigator` and `cadet`, and an empty group `flight-log-readers`. The task is to give read access to `navigator` only, through that group.
