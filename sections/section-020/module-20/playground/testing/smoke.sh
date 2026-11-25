#!/usr/bin/env bash
# Runs the commands that the module pages and the playground guide teach, in
# an order that keeps the state each page expects, against the live
# playground, and fails when one of them does not give the result the page
# describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster, so the `export KUBECONFIG=...` lines of the pages are not
# repeated here.
set -euo pipefail
playground=ats-033-playground-020-02
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-$playground}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-$playground}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
# No page of this module runs a node command, so "$engine" and "$cluster" are
# only part of the shared guard settings.
: "$engine" "$cluster"
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
# Files that the pages save land in the current directory, as for the reader.
cd "$work_directory"

# Write the code block that follows "Save this as `<file>`" on a page into the
# work directory.
save_file_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'Save this as `' + re.escape(name) + r'`[^`]*?```[a-z]*\n(.*?)```', text, re.S)
if not match:
    sys.exit('no code block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
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

# kubectl auth can-i prints yes or no; a no ends with status 1, as the pages say.
can_i() {
  kubectl auth can-i "$@" 2>/dev/null || true
}

# The playground starts ready: two probe replicas, shuttle and drifter.
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=120s
expect_equal 'the private context is selected' "$(kubectl config current-context)" "$context"

# Roles, ClusterRoles And Bindings
page=course-010-roles-clusterroles-and-bindings.md
save_file_from_page "$page" serviceaccount-report-reader.yaml
save_file_from_page "$page" role-probe-code-reader.yaml
save_file_from_page "$page" rolebinding-report-reader.yaml
applied="$(kubectl apply -f serviceaccount-report-reader.yaml -f role-probe-code-reader.yaml -f rolebinding-report-reader.yaml)"
printf '%s\n' "$applied"
expect 'apply creates the ServiceAccount report-reader' "$applied" 'serviceaccount/report-reader created'
expect 'apply creates the Role probe-code-reader' "$applied" 'role.rbac.authorization.k8s.io/probe-code-reader created'
expect 'apply creates the RoleBinding report-reader-probe-code' "$applied" 'rolebinding.rbac.authorization.k8s.io/report-reader-probe-code created'
account=system:serviceaccount:starfleet:report-reader
expect_equal 'report-reader may get configmap/probe-code' "$(can_i get configmap/probe-code --as="$account" -n starfleet)" yes
expect_equal 'report-reader may not list ConfigMaps' "$(can_i list configmaps --as="$account" -n starfleet)" no
expect_equal 'report-reader may not get probe-code in outpost' "$(can_i get configmap/probe-code --as="$account" -n outpost)" no
save_file_from_page "$page" rolebinding-report-reader-view.yaml
expect 'apply creates the RoleBinding report-reader-view' "$(kubectl apply -f rolebinding-report-reader-view.yaml)" 'rolebinding.rbac.authorization.k8s.io/report-reader-view created'
expect_equal 'view lets report-reader list pods in starfleet' "$(can_i list pods --as="$account" -n starfleet)" yes
expect_equal 'report-reader may not list pods in outpost' "$(can_i list pods --as="$account" -n outpost)" no
expect_equal 'view does not include Secrets' "$(can_i get secrets --as="$account" -n starfleet)" no

# Wildcards, cluster-admin And Escalation
page=course-020-wildcards-cluster-admin-and-escalation.md
save_file_from_page "$page" serviceaccount-restarter.yaml
save_file_from_page "$page" rolebinding-restarter-admin.yaml
applied="$(kubectl apply -f serviceaccount-restarter.yaml -f rolebinding-restarter-admin.yaml)"
printf '%s\n' "$applied"
expect 'apply creates the ServiceAccount restarter' "$applied" 'serviceaccount/restarter created'
expect 'apply creates the RoleBinding restarter-admin' "$applied" 'rolebinding.rbac.authorization.k8s.io/restarter-admin created'
account=system:serviceaccount:outpost:restarter
expect_equal 'admin lets restarter get Secrets' "$(can_i get secrets --as="$account" -n outpost)" yes
expect_equal 'admin lets restarter create RoleBindings' "$(can_i create rolebindings --as="$account" -n outpost)" yes
save_file_from_page "$page" role-restarter.yaml
save_file_from_page "$page" rolebinding-restarter.yaml
applied="$(kubectl apply -f role-restarter.yaml -f rolebinding-restarter.yaml)"
printf '%s\n' "$applied"
expect 'apply creates the Role restarter' "$applied" 'role.rbac.authorization.k8s.io/restarter created'
expect 'apply creates the RoleBinding restarter' "$applied" 'rolebinding.rbac.authorization.k8s.io/restarter created'
expect 'delete removes restarter-admin' "$(kubectl -n outpost delete rolebinding restarter-admin)" 'rolebinding.rbac.authorization.k8s.io "restarter-admin" deleted'
expect_equal 'restarter may no longer get Secrets' "$(can_i get secrets --as="$account" -n outpost)" no
expect_equal 'restarter may patch Deployments' "$(can_i patch deployments.apps --as="$account" -n outpost)" yes

# Audit Permissions With kubectl auth can-i
# This page needs the wide ops-agent of the start state, so it runs before the
# guide, which removes that access.
page=course-030-audit-permissions-with-kubectl-auth-can-i.md
account=system:serviceaccount:starfleet:ops-agent
expect_equal 'ops-agent may delete Secrets in outpost' "$(can_i delete secrets --as="$account" -n outpost)" yes
expect_equal 'ops-agent may do everything' "$(can_i '*' '*' --as="$account")" yes
rules="$(kubectl auth can-i --list --as="$account" -n starfleet)"
printf '%s\n' "$rules"
expect_match 'the list of ops-agent has *.* with [*]' "$rules" '^\*\.\*[[:space:]]+\[\][[:space:]]+\[\][[:space:]]+\[\*\]'
expect_match 'the list also shows selfsubjectaccessreviews' "$rules" '^selfsubjectaccessreviews'
aggregation="$(kubectl get clusterrole view -o jsonpath='{.aggregationRule}{"\n"}')"
printf '%s\n' "$aggregation"
expect 'view has a label selector for aggregate-to-view' "$aggregation" '"rbac.authorization.k8s.io/aggregate-to-view":"true"'
feeders="$(kubectl get clusterrole -l rbac.authorization.k8s.io/aggregate-to-view=true)"
printf '%s\n' "$feeders"
expect_match 'ClusterRoles feed view' "$feeders" '^system:aggregate-to-view '
bindings="$(kubectl get clusterrolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name)"
printf '%s\n' "$bindings"
expect_match 'cluster-admin is bound to system:masters' "$bindings" '^cluster-admin +cluster-admin +system:masters$'
expect_match 'cluster-admin is bound to kubeadm:cluster-admins' "$bindings" '^kubeadm:cluster-admins +cluster-admin +kubeadm:cluster-admins$'
expect_match 'ops-agent-admin binds ops-agent to cluster-admin' "$bindings" '^ops-agent-admin +cluster-admin +ops-agent$'
rolebindings="$(kubectl get rolebindings --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name)"
printf '%s\n' "$rolebindings"
expect_match 'the RoleBinding ops-wide is listed' "$rolebindings" '^starfleet +ops-wide +ops-wide +ops-agent$'
wildcards="$(kubectl get roles,clusterroles --all-namespaces -o yaml | grep -n -B6 '\- .\*.')"
expect 'the wildcard search finds the Role ops-wide' "$wildcards" 'name: ops-wide'
expect 'the wildcard search finds cluster-admin' "$wildcards" 'name: cluster-admin'
default_rules="$(kubectl auth can-i --list --as=system:serviceaccount:starfleet:default -n starfleet)"
printf '%s\n' "$default_rules"
# Only the rules every authenticated caller receives: the self reviews and
# non-resource URLs (lines with an empty first column).
extra_rules="$(printf '%s\n' "$default_rules" | sed 1d | grep -Ev '^(selfsubject[a-z]*reviews\.[a-z0-9.]+ |[[:space:]])' || true)"
expect_equal 'default in starfleet holds only the basic rules' "$extra_rules" ''

# Guided Practice: Replace A Wildcard Role And cluster-admin Binding
# The guide gives no YAML: the reader writes the Role and RoleBinding. The
# objects below are the ones the guide describes (get and list on pods, get on
# pods/log, a RoleBinding of the same name).
page=playground/docs/overview.md
role="$(kubectl -n starfleet get role ops-wide -o yaml)"
expect 'guide: ops-wide allows every verb' "$role" "verbs:"
expect_match 'guide: ops-wide has a wildcard' "$role" "^  - '\\*'$"
expect_match 'guide: the RoleBinding ops-wide uses Role/ops-wide' "$(kubectl -n starfleet get rolebinding ops-wide -o wide)" '^ops-wide +Role/ops-wide .*starfleet/ops-agent'
expect_match 'guide: ops-agent-admin uses ClusterRole/cluster-admin' "$(kubectl get clusterrolebinding ops-agent-admin -o wide)" '^ops-agent-admin +ClusterRole/cluster-admin .*starfleet/ops-agent'
cat >role-ops-agent-reader.yaml <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ops-agent-reader
  namespace: starfleet
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
YAML
cat >rolebinding-ops-agent-reader.yaml <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ops-agent-reader
  namespace: starfleet
subjects:
- kind: ServiceAccount
  name: ops-agent
  namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ops-agent-reader
YAML
kubectl apply -f role-ops-agent-reader.yaml
kubectl apply -f rolebinding-ops-agent-reader.yaml
kubectl delete clusterrolebinding ops-agent-admin
kubectl -n starfleet delete rolebinding ops-wide
kubectl -n starfleet delete role ops-wide
expect_equal 'guide: ops-agent may list pods in starfleet' "$(can_i list pods --as="$account" -n starfleet)" yes
expect_equal 'guide: ops-agent may not delete pods' "$(can_i delete pods --as="$account" -n starfleet)" no
expect_equal 'guide: ops-agent may not list pods in outpost' "$(can_i list pods --as="$account" -n outpost)" no
rules="$(kubectl auth can-i --list --as="$account" -n starfleet)"
printf '%s\n' "$rules"
expect_match 'guide: the list has get and list on pods' "$rules" '^pods +\[\] +\[\] +\[get list\]'
expect_match 'guide: the list has get on pods/log' "$rules" '^pods/log +\[\] +\[\] +\[get\]'
expect_equal 'guide: the list has no wildcard rule left' "$(printf '%s\n' "$rules" | grep -c '^\*\.\*' || true)" 0

if [[ "$failures" -gt 0 ]]; then
  printf 'FAIL: %s of %s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi
printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
