---
exam_objectives:
- Using least-privilege identity and access management
---
# Mount A Short-Lived Projected Token

The learner adds a projected `serviceAccountToken` volume to the Deployment `relay` with the path `bridge-token`, the audience `bridge-api` and `expirationSeconds: 600`, mounted at `/var/run/secrets/tokens`. The learner also turns off the default token mount for the Pod.

The lab uses its own pinned kind cluster with one control-plane node and the preloaded `busybox:1.37.0` image. The grader reads the token file inside the running Pod, decodes the JWT payload and checks `aud`, `exp - iat` and the ServiceAccount name. A second check confirms that the default token directory is absent.

Live run on 2026-11-17: `astrona test` with `testing/verify-start.sh` proved that both outcomes fail on the starting state. After `solution/apply.sh`, both outcomes passed (`2 passed, 0 failed`, `PROCTOR: PASS`). Every command output in `solution.md` comes from a manual walkthrough on the same pinned image that day; the decoded token output is shortened and says so.
