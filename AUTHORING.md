# Focused lessons and independent labs

Read `CLAUDE.md` for this course's writing and platform conventions. Use
`LAB-COVERAGE.md` to trace a task to its preparation lesson, grader and lifecycle.
The map records assessed outcomes; a live workflow run supplies verification.

## Teaching and task boundaries

Place each lab immediately after the lesson that teaches its graded skill. Keep
lessons self-contained and explain the responsible component, the inspection,
the bounded change and the evidence of success. Preserve playground start,
renew and destroy markers. Course pages end with their specific common pitfalls;
the platform inserts the registered lab afterwards.

Default to three to five related tasks and 10–15 minutes of student work. Existing
shorter exercises may retain two tasks when they cover one complete outcome.
Count startup and reconciliation separately. Split independent faults or different
investigations; do not add steps merely to reach a count. Keep integration work in
capstones. Each lab must bootstrap independently, with only its assigned missing
result or fault.

When a lesson introduces a new assessable skill, map it to an observable result
and grader. Add a lab if no existing task covers it. Supporting concepts can
prepare a later assessment. Change the teaching, task, reference solution and
grader together; do not grade an untaught operation.

## Runtime and grading contract

Retain runtime IDs, course registration, question-bank IDs and domain weights.
Leave `task_kind`, `tags` and `topic` to their existing tooling. Keep technical
pages in draft until review. Use a unique namespace for each module lab and keep
all context and node ownership guards.

Scripts read `ASTRONA_KUBE_CONTEXT`, `ASTRONA_KIND_CLUSTER` and
`ASTRONA_CONTAINER_ENGINE`, with their existing local defaults. The pinned CLI in
CI needs the test context exported explicitly. Do not remove a guard to make a
test pass, or operate on unrelated clusters.

Score each required repair or submitted finding with its own validation script.
Preserving staged evidence and unrelated workloads is a constraint, not a scored
outcome. Grade live behavior and compare reports with current source evidence.
Reject stale identities and bypasses. State when a configuration-only exercise
does not run the actual detector or enforcement mechanism.

Each module lab runs `testing/verify-start.sh`, `solution/apply.sh`, then
`testing/wait-solved.sh`. Every scored outcome must fail before the solution and
pass afterwards. A timeout, missing executable or API connection error is not
proof of an unfinished task. Keep shared runtime helpers identical across module
labs and add regression tests for false positives and grading bypasses.

## Verification and review

Install `scripts/ci/requirements.txt`, then run:

```sh
python3 scripts/ci/test-course-structure.py
python3 scripts/ci/check-course-structure.py
python3 scripts/ci/test-grading-runtime.py
python3 scripts/ci/lab-coverage.py
scripts/ci/list-environments.sh
```

Run each changed lab's `testing/test-*.py` files and validate its Astrona
configuration. GitHub Actions discovers labs and playgrounds, tests their runtime
lifecycles and uploads diagnostics on failure. Shared scripts and workflow changes
select every environment. The `all environments pass` job is the aggregate result.
Do not describe static validation or a queued workflow as a passing lifecycle.

Use one review PR for this course, with separate commits for independent changes.
Push updates to its existing branch and leave it unmerged for manual review.

To resume in a new session, say:

> Continue this course's focused lesson/lab rollout on its existing PR branch.
> Read CLAUDE.md, AUTHORING.md and LAB-COVERAGE.md, inspect the branch diff and
> latest Actions failures, preserve the existing work, and finish the required
> checks. Keep one PR for this repository, push separate commits, and leave it
> unmerged for manual review.

## Teaching and assessment coverage

Maintain explicit preparation in [TEACHING-COVERAGE.yaml](TEACHING-COVERAGE.yaml).
Every lab needs earlier preparation in its own module, or its section for a
capstone. List technical readings without a module assessment in
`additional_readings`. Regenerate [LAB-COVERAGE.md](LAB-COVERAGE.md) and review
both directions. A link does not prove that the whole lesson is assessed;
record remaining practical gaps in [COVERAGE-REVIEW.md](COVERAGE-REVIEW.md).

Use kind for Kubernetes behavior supported by the installed controllers and
network plugin. Use QEMU when the student needs an independent kernel, host
service or mandatory access control. Check real behavior: a RuntimeClass name,
stored rule or encryption setting alone does not prove isolation, detection or
encrypted traffic. Teach every required submission field before asking for it.

Run `python3 scripts/ci/test-teaching-coverage.py` alongside the structure tests.
Preserve the existing branch and PR, push logical commits, and leave the merge
for manual review.
