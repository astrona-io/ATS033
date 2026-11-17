---
exam_objectives:
- Minimize host OS footprint (reduce attack surface)
---
# Remove Host Access From A Workload

The setup script applies the `starfleet-033-010-03-01` namespace and the `beacon` Deployment (`hostNetwork`, `hostPID`, `privileged: true`, a `hostPath` volume for `/var/log`) and waits for the rollout. The learner rewrites the pod template.

Four outcomes are graded, each with a field check and a behaviour check through `kubectl exec`. `no-host-namespaces` (1 point) needs no host namespace fields, a pod IP address different from the host IP address and no `kubelet` in `ps`. `scratch-volume` (1 point) needs no `hostPath` volume, an `emptyDir` at `/scratch` and a successful write there. `non-root-unprivileged` (2 points) needs `privileged: false`, `allowPrivilegeEscalation: false`, `runAsNonRoot: true`, `runAsUser: 10001` on the container or the pod, `ALL` capabilities dropped and `id -u` printing `10001`. `read-only-root` (1 point) needs `readOnlyRootFilesystem: true` and a failing write to `/`. Every outcome also needs the original image and command and exactly one Running, Ready pod. The earlier ConfigMap record and the namespace Pod Security Admission label were removed: Pod Security Admission has its own lab.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution (`solution/deployment-beacon.yaml`) is applied and every outcome must pass.

Live run on 2026-11-17 (kind `v1.35.0`, Podman): `astrona test` passed with 5/5 points, and `verify-start.sh` failed all four outcomes on the starting state. The commands and output in `solution.md` come from a manual run of the same environment.
