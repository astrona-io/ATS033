# Reusable Question Banks

`assessments/index.yaml` lists banks in teaching order. Each bank uses schema
version 1 and the contract in `schemas/question-bank.schema.json`. This is an
authoring format for future application integration, not an existing Astrona
quiz API. No YAML question file is registered as a Markdown reading.

Banks follow their declared module summaries. Larger domains use an intermediate
checkpoint after the third section and a final domain review; smaller domains
use a final domain review. The index records covered sections and teaching order. Banks contain 5–15 original single-choice
questions, scoped to concepts taught in the course. They remain draft for review.

## Fields And Rendering

- `id`: stable bank or question identity; preserve it when editing wording.
- `scope`: section or domain checkpoint.
- `placement`: relative reading path after which the checkpoint belongs.
- `learning_objective`: the measurable outcome checked by the question.
- `source_readings`: author traceability to the teaching; not learner navigation.
- `prompt`: learner-visible question text.
- `options`: stable option IDs, answer text and per-option feedback.
- `correct_option`: the ID of the single correct option.
- `explanation`: feedback reinforcing the supported answer.

The application should send only the question ID, prompt and option IDs/text to
the learner before submission. Keep `correct_option`, `explanation` and option
explanations on the server until feedback is permitted. Match answers by option
ID, not display position, so a later renderer can shuffle choices safely.

The banks contain answer keys and are public learning material, so this is not
a secure examination bank. Do not treat scores as an official CKS result.

## Hands-On Coverage

This course has 12 ungraded module playgrounds (7 on kind, 5 on a qemu VM) and 37 graded labs (20 on kind, 17 on a qemu VM). Each lab sits right after the reading it practises, with its task before and its solution after. The qemu labs and playgrounds work on node files, services, packages, sshd, ufw, static Pods, the kubelet, etcd or AppArmor, and run in a one-node kubeadm virtual machine built from the multi-arch `ubuntu-qcow2-image:24.04-cks` image. Every lab passed `astrona validate` and `astrona test` on its own runtime.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Close An Unneeded Listener On A Node; Purge An Unneeded Package From A Node |
| 010/02 | Restrict SSH Logins In sshd_config; Close Unused And Duplicate Root Accounts |
| 010/03 | Remove Host Access From A Workload; Enforce The Baseline Pod Security Standard; Dedicate A Worker Node To One Workload |
| 020/01 | Grant Read Access Through A Group; Lock And Expire A Departed Account; Revoke A Leaver's Access Everywhere; Record Every Change To The Sudo Rules |
| 020/02 | Scope Access With resourceNames And A RoleBinding; Replace Wildcard And Cluster-Admin Access; Find Hidden RBAC Grants |
| 020/03 | Give A Workload Its Own ServiceAccount; Mount A Short-Lived Projected Token; Close The Default ServiceAccount |
| 030/01 | Bind A Host-Network Service To Loopback; Block A Host Port With ufw; Default-Deny Ingress With One Allowed Client |
| 030/02 | Close An Accidental NodePort; Answer A NodePort Only On Nodes With Endpoints; Audit And Close Unapproved Service Exposure |
| 030/03 | Bind The Scheduler To Loopback; Remove Anonymous Access From RBAC Bindings; Close The Kubelet API To Anonymous Callers; Restrict The etcd Data Directory |
| 040/01 | Install And Use A Localhost seccomp Profile; Load An AppArmor Profile And Attach It To A Pod; Harden A Deployment To The Restricted Pod Security Level; Fix A Pod That References A Missing seccomp Profile |
| 040/02 | Apply The RuntimeDefault seccomp Profile To Deployments; Block File Deletion With A Localhost seccomp Profile; Find And Fix A Blocked System Call In A seccomp Profile |
| 040/03 | Switch An AppArmor Profile From Complain To Enforce Mode; Set An AppArmor Profile For One Container; Drop All Capabilities Except NET_BIND_SERVICE |
