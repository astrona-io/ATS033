# Teaching and assessment review

The course has teaching material for its registered lab tasks, but its readings cover a broader set of skills than its graders. Passing all environment tests proves the implemented lifecycles; it does not establish complete practical coverage of every learning objective.

`TEACHING-COVERAGE.yaml` names the preparation set for every lab. `LAB-COVERAGE.md` renders both directions: lab to preparation and reading to assessment. A preparation link means the reading teaches something used by that task, not that every operation in the reading is graded. The additional-reading list makes material without a module assessment visible. The course has no capstone lab.

## Readings without a graded lab

Three technical readings are listed under `additional_readings` and have no lab of their own. Each one has hands-on steps in its module playground, which is ungraded. Related skills are graded in other modules, but the coverage map does not link these readings to those labs, so the map does not count them as preparation.

| Reading | Ungraded practice | Related graded labs in other modules |
| --- | --- | --- |
| `sections/section-010/module-10/course-040-privileged-host-interfaces.md` | 010/01 playground | 010/03: Remove Host Access From A Workload; Enforce The Baseline Pod Security Standard |
| `sections/section-020/module-10/course-030-kubernetes-identities-and-rbac.md` | 020/01 playground | 020/02: Scope Access With resourceNames And A RoleBinding; 020/03: Close The Default ServiceAccount |
| `sections/section-030/module-10/course-040-nodeports-control-plane-ports-and-api-access.md` | 030/01 playground | 030/02: Close An Accidental NodePort; 030/03: Remove Anonymous Access From RBAC Bindings; Close The Kubelet API To Anonymous Callers |

## Remaining practical gaps and boundaries

- A grader checks the state it can observe when it runs. Each command in `testing/check.py` has a 20-second timeout. A passing outcome does not prove that the state stays the same later or that no other path to the same weakness exists.
- The 17 qemu labs run in a one-node kubeadm virtual machine, so the control plane node and the worker node are the same machine. Tasks that need a separate worker node run on kind.
- The kind nodes are containers on the host, so they share the host kernel. Labs that load AppArmor profiles or change host services, packages, sshd, ufw, static Pods, the kubelet or etcd run in the qemu virtual machine instead.
- `README.md` records that every lab passed `astrona validate` and `astrona test` on its own runtime. Continuous integration starts each changed playground with `scripts/ci/test-playground.sh`; this file records no playground result.
- The YAML question banks are public and contain their answer keys. They are practice material, not a secure or official exam bank.

## Runtime choice

Use kind for Kubernetes API objects, RBAC, ServiceAccounts, admission, scheduling, Services and NetworkPolicy, and for seccomp profiles on a kind node. Use QEMU for a separate Linux kernel, host service and package lifecycle, sshd and ufw, static Pods, the kubelet, etcd and AppArmor. A runtime name or a configuration file is never proof that the intended mechanism is active; the grader must observe it.

Keep each new lab immediately after its preparation reading, and leave merging to the reviewer.
