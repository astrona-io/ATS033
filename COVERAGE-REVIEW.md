# Teaching and assessment review

The course has teaching material for its registered lab tasks, but its readings cover a broader set of skills than its graders. Passing all environment tests proves the implemented lifecycles; it does not establish complete practical coverage of every learning objective.

`TEACHING-COVERAGE.yaml` names the preparation set for every lab. `LAB-COVERAGE.md` renders both directions: lab to preparation and reading to assessment. A preparation link means the reading teaches something used by that task, not that every operation in the reading is graded. The additional-reading list makes material without a module assessment visible. Capstones combine selected skills and do not silently count as coverage of every reading.

## Live assessment additions

The SSH assessment now reloads a running sshd and tests fresh permitted and rejected logins. A separate QEMU lab applies nftables rules and tests trusted and untrusted clients while preserving required traffic.

## Remaining practical gaps and boundaries

- The AppArmor VM proves host-process file enforcement. Kubernetes appArmorProfile selection remains conditional playground practice.
- Package removal has no dedicated module assessment. SSH uses a separate training listener; it does not modify the VM management service.

## Runtime choice

Use kind for Kubernetes API objects, admission, scheduling and network tests whose required controllers or network plugin are installed. Use QEMU for an independent Linux kernel, host service lifecycle, mandatory access control or kernel event collection. A runtime name or ConfigMap is never proof that its intended runtime or encryption mechanism is active.

Keep each new lab immediately after its preparation reading. Preserve the existing PR for this repository, push separate commits, and leave merging to the reviewer.
