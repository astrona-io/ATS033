---
exam_objectives:
- Minimize external access to the network
---
# Bind The Scheduler To Loopback

The bootstrap seeds the pod `shuttle` on the worker, then changes `--bind-address=127.0.0.1` to `--bind-address=0.0.0.0` in `/etc/kubernetes/manifests/kube-scheduler.yaml` on the control-plane node and waits until kube-scheduler listens on `*:10259`. The learner restores the loopback bind address.

Outcomes (1 point each):

- `scheduler-loopback-listener`: the running kube-scheduler command line (`pgrep -a`) has `--bind-address=127.0.0.1`, `ss -tln` shows port 10259 on `127.0.0.1` only, and `curl -sk https://127.0.0.1:10259/healthz` on the node returns `ok`.
- `scheduler-port-closed`: `wget` from `shuttle` to `https://<control-plane InternalIP>:10259/healthz` fails with `Connection refused`.

Guards: the kube-scheduler mirror pod is Ready and `shuttle` runs on the worker.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. Live run on 2026-11-17 (kind `v1.35.0`, Podman): on the start state `shuttle` got `ok` from the control-plane address; after the manifest fix kube-scheduler listened on `127.0.0.1:10259`, `shuttle` got `Connection refused`, and both outcomes passed.
