#!/usr/bin/env bash
# Runs the commands that the module pages and the playground guide teach
# against the live playground, and fails when one of them does not give the
# result the page describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster, so the `export KUBECONFIG=...` lines of the pages are not
# repeated here. The pages write `podman exec` for node commands; this script
# uses "$engine" instead, because CI runs kind on docker.
# The module pages need the beacon Deployment of the start state, and the
# guide changes it, so the guide runs last.
set -euo pipefail
playground=ats-033-playground-010-03
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-$playground}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-$playground}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
# Files that the pages save land in the current directory, as for the reader.
cd "$work_directory"
node_name="$cluster-control-plane"
worker_name="$cluster-worker"

# Write the code block that follows "Save this as `<file>`:" on a page into the
# work directory. The optional third argument picks the n-th such block, for a
# page that saves a new version of the same file.
save_file_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" "${3:-1}" <<'PY'
import re, sys
page, name, target, wanted = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
text = open(page).read()
matches = re.findall(r'Save this as `' + re.escape(name) + r'`[^:]*:\s*```[a-z]*\n(.*?)```', text, re.S)
if len(matches) < wanted:
    sys.exit('no code block ' + str(wanted) + ' for ' + name + ' in ' + page)
open(target, 'w').write(matches[wanted - 1])
PY
}

checks=0
# A failed check is counted, and the script goes on, so one run shows every
# difference between a page and the live playground. It exits 1 at the end.
failures=0
expect() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == *"$3"* ]] || { printf 'FAIL: %s\nwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; failures=$((failures + 1)); }
}

expect_equal() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == "$3" ]] || { printf 'FAIL: %s\nwanted exactly: %s\ngot: %s\n' "$1" "$3" "$2" >&2; failures=$((failures + 1)); }
}

expect_match() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  printf '%s\n' "$2" | grep -Eq -- "$3" || { printf 'FAIL: %s\nwanted a line matching: %s\ngot: %s\n' "$1" "$3" "$2" >&2; failures=$((failures + 1)); }
}

expect_no_match() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  if printf '%s\n' "$2" | grep -Eq -- "$3"; then
    printf 'FAIL: %s\nwanted no line matching: %s\ngot: %s\n' "$1" "$3" "$2" >&2
    failures=$((failures + 1))
  fi
}

# The node command of the kubelet page, on the engine that runs the node.
run_on_node() { "$engine" exec "$node_name" "$@"; }

# Print "<pod address> <node address>" of a pod, the two values that the
# -o wide output of the pages compares.
pod_and_node_address() {
  kubectl -n "$1" get pod "$2" -o jsonpath='{.status.podIP} {.status.hostIP}'
}

# Wait up to 60 seconds until a command prints text that contains the pattern,
# then print that text.
wait_for_output() {
  local pattern=$1 attempt output=''
  shift
  for attempt in $(seq 1 30); do
    output="$("$@" 2>&1 || true)"
    grep -Eq -- "$pattern" <<<"$output" && break
    sleep 2
  done
  printf '%s\n' "$output"
}

expect_equal 'the context is the playground' "$(kubectl config current-context)" "kind-astro-$playground"

# Host Namespaces, hostPath And Privileged Containers
page=course-010-host-namespaces-hostpath-and-privileged-containers.md
save_file_from_page "$page" pod-host-view.yaml
expect_equal 'host access: apply creates host-view' "$(kubectl apply -f pod-host-view.yaml)" 'pod/host-view created'
expect_equal 'host access: host-view becomes Ready' "$(kubectl -n starfleet wait --for=condition=Ready pod/host-view --timeout=120s)" 'pod/host-view condition met'
processes="$(kubectl -n starfleet exec host-view -- ps)"
printf '%s\n' "$processes"
expect_match 'host access: the pod sees the kubelet of the node' "$processes" 'kubelet'
expect_match 'host access: the pod sees containerd of the node' "$processes" 'containerd'
wide="$(kubectl -n starfleet get pod host-view -o wide)"
printf '%s\n' "$wide"
read -r pod_address node_address <<<"$(pod_and_node_address starfleet host-view)"
expect_equal 'host access: host-view has the node address' "$pod_address" "$node_address"
expect 'host access: the IP column shows the node address' "$wide" " $node_address "
read -r pod_address node_address <<<"$(pod_and_node_address starfleet shuttle)"
[[ "$pod_address" != "$node_address" ]] && same=no || same=yes
expect_equal 'host access: shuttle has an address from the pod network' "$same" no
expect 'host access: delete removes host-view' "$(kubectl -n starfleet delete pod host-view)" 'pod "host-view" deleted'

# Enforce Limits With Pod Security Admission
page=course-020-enforce-limits-with-pod-security-admission.md
dry_run="$(kubectl label namespace starfleet pod-security.kubernetes.io/enforce=baseline --dry-run=server --overwrite 2>&1)"
printf '%s\n' "$dry_run"
expect 'admission: the dry run warns about the starfleet pods' "$dry_run" 'Warning: existing pods in namespace "starfleet" violate the new PodSecurity enforce level "baseline:latest"'
expect_match 'admission: the beacon pod is in the warnings' "$dry_run" '^Warning: beacon-[a-z0-9]+-[a-z0-9]+: host namespaces, hostPath volumes, privileged$'
expect_no_match 'admission: no other pod is in the warnings' "$dry_run" '^Warning: (probe|shuttle)'
expect 'admission: the dry run changes nothing' "$dry_run" 'namespace/starfleet labeled (server dry run)'
expect_equal 'admission: starfleet has no enforce label' "$(kubectl get namespace starfleet -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" ''
expect_equal 'admission: label outpost' "$(kubectl label namespace outpost pod-security.kubernetes.io/enforce=baseline)" 'namespace/outpost labeled'
save_file_from_page "$page" deployment-scanner.yaml 1
expect_equal 'admission: the API server accepts the Deployment' "$(kubectl apply -f deployment-scanner.yaml)" 'deployment.apps/scanner created'
events="$(wait_for_output 'FailedCreate' kubectl -n outpost get events --field-selector reason=FailedCreate)"
printf '%s\n' "$events"
expect 'admission: the ReplicaSet records the rejection' "$events" 'violates PodSecurity "baseline:latest": host namespaces (hostPID=true)'
expect_match 'admission: the event belongs to the ReplicaSet' "$events" 'replicaset/scanner-[a-z0-9]+ '
deployment="$(kubectl -n outpost get deployment scanner)"
printf '%s\n' "$deployment"
expect_match 'admission: the Deployment has no ready replica' "$deployment" '^scanner +0/1 '
save_file_from_page "$page" deployment-scanner.yaml 2
expect_equal 'admission: apply updates the template' "$(kubectl apply -f deployment-scanner.yaml)" 'deployment.apps/scanner configured'
expect 'admission: the fixed pod passes baseline' "$(kubectl -n outpost rollout status deployment/scanner --timeout=120s)" 'deployment "scanner" successfully rolled out'
expect 'admission: delete removes the experiment' "$(kubectl -n outpost delete deployment scanner)" 'deployment.apps "scanner" deleted'
expect_equal 'admission: the trailing dash removes the label' "$(kubectl label namespace outpost pod-security.kubernetes.io/enforce-)" 'namespace/outpost unlabeled'

# Kubelet Settings And Dedicated Nodes
page=course-030-kubelet-settings-and-dedicated-nodes.md
settings="$(run_on_node grep -A4 -E 'anonymous|authorization|readOnlyPort' /var/lib/kubelet/config.yaml)"
printf '%s\n' "$settings"
expect 'kubelet: anonymous requests are off' "$settings" "$(printf '  anonymous:\n    enabled: false')"
expect 'kubelet: the kubelet asks the API server' "$settings" "$(printf 'authorization:\n  mode: Webhook')"
expect_no_match 'kubelet: the read-only port is not set' "$settings" 'readOnlyPort: [1-9]'
listeners="$(run_on_node ss -tln)"
printf '%s\n' "$listeners"
expect_match 'kubelet: port 10250 listens' "$listeners" ':10250 '
expect_no_match 'kubelet: port 10255 is absent' "$listeners" ':10255 '
expect_equal 'kubelet: an anonymous request is refused' "$(run_on_node curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:10250/pods)" 401
expect_equal 'dedicated: label the worker' "$(kubectl label node "$worker_name" node-restriction.kubernetes.io/dedicated=ledger)" "node/$worker_name labeled"
expect_equal 'dedicated: taint the worker' "$(kubectl taint nodes "$worker_name" dedicated=ledger:NoSchedule)" "node/$worker_name tainted"
save_file_from_page "$page" pod-ledger.yaml
save_file_from_page "$page" pod-visitor.yaml
expect_equal 'dedicated: apply both pods' "$(kubectl apply -f pod-ledger.yaml -f pod-visitor.yaml)" "$(printf 'pod/ledger created\npod/visitor created')"
kubectl -n starfleet wait --for=condition=Ready pod/ledger --timeout=120s
description="$(wait_for_output 'FailedScheduling' kubectl -n starfleet describe pod visitor)"
printf '%s\n' "$description"
wide="$(kubectl -n starfleet get pod ledger visitor -o wide)"
printf '%s\n' "$wide"
expect_match 'dedicated: ledger runs on the worker' "$wide" "^ledger +1/1 +Running +0 .* $worker_name "
expect_match 'dedicated: visitor stays Pending' "$wide" '^visitor +0/1 +Pending +0 '
expect 'dedicated: the scheduler reports untolerated taints' "$description" 'untolerated taint'
# The Kubernetes 1.35 scheduler event counts the untolerated taints but does
# not name them (job 137304436318), and the page does not claim more.
deleted="$(kubectl -n starfleet delete pod ledger visitor)"
expect 'dedicated: delete removes ledger' "$deleted" 'pod "ledger" deleted'
expect 'dedicated: delete removes visitor' "$deleted" 'pod "visitor" deleted'
expect_equal 'dedicated: the trailing dash removes the taint' "$(kubectl taint nodes "$worker_name" dedicated=ledger:NoSchedule-)" "node/$worker_name untainted"
expect_equal 'dedicated: the trailing dash removes the label' "$(kubectl label node "$worker_name" node-restriction.kubernetes.io/dedicated-)" "node/$worker_name unlabeled"

# Guided Practice: Remove Host Access From A Workload
page=playground/docs/overview.md
expect_equal 'guide: the template asks for host access' "$(kubectl -n starfleet get deployment beacon -o jsonpath='{.spec.template.spec.hostNetwork} {.spec.template.spec.hostPID} {.spec.template.spec.containers[0].securityContext.privileged}{"\n"}')" 'true true true'
old_pod="$(kubectl -n starfleet get pods -l app=beacon -o jsonpath='{.items[0].metadata.name}')"
kubectl -n starfleet get pods -l app=beacon -o wide
read -r pod_address node_address <<<"$(pod_and_node_address starfleet "$old_pod")"
expect_equal 'guide: the beacon pod has the node address' "$pod_address" "$node_address"
save_file_from_page "$page" deployment-beacon.yaml
save_file_from_page "$page" configmap-workload-review.yaml
expect_equal 'guide: apply changes the Deployment' "$(kubectl apply -f deployment-beacon.yaml)" 'deployment.apps/beacon configured'
expect 'guide: the new pod rolls out' "$(kubectl -n starfleet rollout status deployment/beacon --timeout=120s)" 'deployment "beacon" successfully rolled out'
expect_equal 'guide: label starfleet' "$(kubectl label namespace starfleet pod-security.kubernetes.io/enforce=baseline --overwrite)" 'namespace/starfleet labeled'
expect_equal 'guide: record the review' "$(kubectl apply -f configmap-workload-review.yaml)" 'configmap/workload-review created'
template="$(kubectl -n starfleet get deployment beacon -o jsonpath='{.spec.template.spec.hostNetwork} {.spec.template.spec.volumes}{"\n"}')"
printf '%s\n' "$template"
expect_equal 'guide: the template has an empty host network value and only scratch' "$template" ' [{"emptyDir":{},"name":"scratch"}]'
# The old pod ignores the stop signal, so it can run out its grace period.
kubectl -n starfleet wait --for=delete "pod/$old_pod" --timeout=90s
kubectl -n starfleet get pods -l app=beacon -o wide
new_pod="$(kubectl -n starfleet get pods -l app=beacon -o jsonpath='{.items[0].metadata.name}')"
read -r pod_address node_address <<<"$(pod_and_node_address starfleet "$new_pod")"
[[ "$pod_address" != "$node_address" ]] && same=no || same=yes
expect_equal 'guide: the new pod address differs from the node address' "$same" no
dry_run="$(kubectl label namespace starfleet pod-security.kubernetes.io/enforce=baseline --overwrite --dry-run=server 2>&1)"
printf '%s\n' "$dry_run"
expect_no_match 'guide: no pod in starfleet violates baseline' "$dry_run" '^Warning:'
expect_equal 'guide: the API server is ready' "$(kubectl get --raw=/readyz)" ok

if [[ "$failures" -gt 0 ]]; then
  printf 'FAIL: %s of %s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi
printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
