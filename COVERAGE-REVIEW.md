# Teaching and assessment review

The course has teaching material for its registered lab tasks, but its readings cover a broader set of skills than its graders. Passing all environment tests proves the implemented lifecycles; it does not establish complete practical coverage of every learning objective.

`TEACHING-COVERAGE.yaml` names the preparation set for every lab. `LAB-COVERAGE.md` renders both directions: lab to preparation and reading to assessment. A preparation link means the reading teaches something used by that task, not that every operation in the reading is graded. The additional-reading list makes material without a module assessment visible. Capstones combine selected skills and do not silently count as coverage of every reading.

## Remaining practical gaps and boundaries

- The new QEMU lab proves real AppArmor file enforcement. Kubernetes `appArmorProfile` selection remains conditional playground practice; it is not covered by that host-process test.
- SSH hardening currently grades staged configuration and account state in a kind node. It does not prove an actual sshd login or reload.
- Package removal and host firewall procedures have no dedicated module grader. The listener lab proves loopback binding, which is a different control.

These are explicit limits, not completed assessments. When closing one, add or extend a runnable environment, teach the actual commands and evidence, add a live grader with negative cases, and update the mapping. Do not mark a reference procedure as practiced just because it contains a command block.

## Runtime choice

Use kind for Kubernetes API objects, admission, scheduling and network tests whose required controllers or network plugin are installed. Use QEMU for an independent Linux kernel, host service lifecycle, mandatory access control or kernel event collection. A runtime name or ConfigMap is never proof that its intended runtime or encryption mechanism is active.

Keep each new lab immediately after its preparation reading. Preserve the existing PR for this repository, push separate commits, and leave merging to the reviewer.
