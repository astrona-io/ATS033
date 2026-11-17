---
exam_objectives:
- Using least-privilege identity and access management
---
# Give A Workload Its Own ServiceAccount

The learner creates the ServiceAccount `monitor`, binds it to the existing Role `pod-reader` and moves the Deployment `monitor` to it. The learner also sets `automountServiceAccountToken: false` on the Deployment `probe`, which never calls the API server.

The lab uses its own pinned kind cluster with one control-plane node and the preloaded `busybox:1.37.0` image. The grader runs `ls` inside the running Pods and uses exact `kubectl auth can-i` answers. Pods that are still stopping after a rollout are ignored.

Live run on 2026-11-17: `astrona test` with `testing/verify-start.sh` proved that both outcomes fail on the starting state. After `solution/apply.sh`, both outcomes passed (`2 passed, 0 failed`, `PROCTOR: PASS`). Every command output in `solution.md` comes from a manual walkthrough on the same pinned image that day.
