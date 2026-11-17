---
exam_objectives:
- Minimize external access to the network
---
# Restrict The etcd Data Directory

The bootstrap runs `chmod 755 /var/lib/etcd` on the control-plane node. The learner reads `--data-dir` from `/etc/kubernetes/manifests/etcd.yaml` and sets the directory back to mode `700`.

Outcome (2 points):

- `etcd-data-directory-mode`: `stat -c '%a %U %G' /var/lib/etcd` on the control-plane node returns `700 root root`.

Guards: etcd answers `https://127.0.0.1:2379/health` with `"health":"true"` when called with the `apiserver-etcd-client` certificate, and `kubectl get --raw /readyz` returns `ok`.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. Live run on 2026-11-17 (kind `v1.35.0`, Podman): on the start state `stat` showed `755 root root /var/lib/etcd`; after `chmod 700` it showed `700 root root /var/lib/etcd`, etcd reported `{"health":"true","reason":""}`, `/readyz` returned `ok`, and the outcome passed.
