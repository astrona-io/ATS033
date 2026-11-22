#!/usr/bin/env bash
# Runs the commands that the module pages and the playground guide teach, in
# an order that keeps the state each page expects, against the live
# playground, and fails when one of them does not give the result the page
# describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster, so the `export KUBECONFIG=...` lines of the pages are not
# repeated here.
set -euo pipefail
playground=ats-033-playground-020-03
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
expect() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == *"$3"* ]] || { printf 'FAIL: %s\nwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_equal() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == "$3" ]] || { printf 'FAIL: %s\nwanted exactly: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_match() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  printf '%s\n' "$2" | grep -Eq -- "$3" || { printf 'FAIL: %s\nwanted a line matching: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

# kubectl auth can-i prints yes or no; a no ends with status 1, as the pages say.
can_i() {
  kubectl auth can-i "$@" 2>/dev/null || true
}

token_path=/var/run/secrets/kubernetes.io/serviceaccount/token
default_account=system:serviceaccount:starfleet:default

# The playground starts ready: probe, shuttle, drifter and monitor.
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=120s
kubectl -n starfleet rollout status deployment/monitor --timeout=180s
expect_equal 'the private context is selected' "$(kubectl config current-context)" "$context"

# Dedicated ServiceAccounts And automountServiceAccountToken
page=course-01-dedicated-serviceaccounts-and-automount.md
expect_equal 'monitor runs as default' "$(kubectl -n starfleet get pods -l app=monitor -o jsonpath='{.items[0].spec.serviceAccountName}{"\n"}')" default
expect_equal 'monitor holds ca.crt, namespace and token' "$(kubectl -n starfleet exec deploy/monitor -- ls /var/run/secrets/kubernetes.io/serviceaccount)" "$(printf 'ca.crt\nnamespace\ntoken')"
save_file_from_page "$page" serviceaccount-report-agent.yaml
save_file_from_page "$page" deployment-report-agent.yaml
applied="$(kubectl apply -f serviceaccount-report-agent.yaml -f deployment-report-agent.yaml)"
printf '%s\n' "$applied"
expect 'apply creates the ServiceAccount report-agent' "$applied" 'serviceaccount/report-agent created'
expect 'apply creates the Deployment report-agent' "$applied" 'deployment.apps/report-agent created'
kubectl -n starfleet rollout status deployment/report-agent --timeout=180s
expect_equal 'report-agent has no token' "$(kubectl -n starfleet exec deploy/report-agent -- sh -c "test -e $token_path && echo mounted || echo absent")" absent
expect_equal 'report-agent runs as report-agent' "$(kubectl -n starfleet get pods -l app=report-agent -o jsonpath='{.items[0].spec.serviceAccountName}{"\n"}')" report-agent

# Bound Projected Tokens
page=course-02-bound-projected-tokens.md
save_file_from_page "$page" serviceaccount-token-client.yaml
save_file_from_page "$page" pod-token-client.yaml
applied="$(kubectl apply -f serviceaccount-token-client.yaml -f pod-token-client.yaml)"
printf '%s\n' "$applied"
expect 'apply creates the ServiceAccount token-client' "$applied" 'serviceaccount/token-client created'
expect 'apply creates the pod token-client' "$applied" 'pod/token-client created'
kubectl -n starfleet wait --for=condition=Ready pod/token-client --timeout=120s
expect_equal 'the projected token is present' "$(kubectl -n starfleet exec token-client -- sh -c 'test -s /var/run/secrets/tokens/probe-token && echo present || echo absent')" present
expect_equal 'the standard token is absent' "$(kubectl -n starfleet exec token-client -- sh -c "test -e $token_path && echo mounted || echo absent")" absent
# The token is a credential, so check its shape without printing it.
manual_token="$(kubectl -n starfleet create token token-client --duration=10m)"
expect_equal 'create token prints one JWT line' "$(printf '%s\n' "$manual_token" | grep -cE '^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$')" 1
unset manual_token

# Guided Practice: inspect the start state. The guide's fix runs after the
# third page, which needs the RoleBinding and the token Secret it deletes.
page=playground/docs/overview.md
expect_equal 'guide: monitor holds a token' "$(kubectl -n starfleet exec deploy/monitor -- ls /var/run/secrets/kubernetes.io/serviceaccount)" "$(printf 'ca.crt\nnamespace\ntoken')"
expect_match 'guide: default-pod-lister binds Role/pod-lister to default' "$(kubectl -n starfleet get rolebinding default-pod-lister -o wide)" '^default-pod-lister +Role/pod-lister .*starfleet/default'
expect_match 'guide: the token Secret legacy-monitor-token exists' "$(kubectl -n starfleet get secrets --field-selector type=kubernetes.io/service-account-token)" '^legacy-monitor-token +kubernetes.io/service-account-token +3 '

# The Default ServiceAccount And Unused Tokens
page=course-03-the-default-serviceaccount-and-unused-tokens.md
expect_equal 'default may list pods' "$(can_i list pods --as="$default_account" -n starfleet)" yes
bindings="$(kubectl get rolebindings,clusterrolebindings --all-namespaces -o custom-columns=KIND:.kind,NAMESPACE:.metadata.namespace,NAME:.metadata.name,SUBJECTS:.subjects[*].name | grep -w default)"
printf '%s\n' "$bindings"
expect_match 'the bindings that name default include default-pod-lister' "$bindings" '^RoleBinding +starfleet +default-pod-lister +default$'
expect 'delete removes default-pod-lister' "$(kubectl -n starfleet delete rolebinding default-pod-lister)" 'rolebinding.rbac.authorization.k8s.io "default-pod-lister" deleted'
expect_equal 'default may no longer list pods' "$(can_i list pods --as="$default_account" -n starfleet)" no
save_file_from_page "$page" serviceaccount-default.yaml
expect 'apply configures the default ServiceAccount' "$(kubectl apply -f serviceaccount-default.yaml)" 'serviceaccount/default configured'
expect_equal 'default no longer mounts a token' "$(kubectl -n starfleet get serviceaccount default -o jsonpath='{.automountServiceAccountToken}')" false
token_secrets="$(kubectl get secrets --all-namespaces --field-selector type=kubernetes.io/service-account-token)"
printf '%s\n' "$token_secrets"
expect_match 'the list holds legacy-monitor-token in starfleet' "$token_secrets" '^starfleet +legacy-monitor-token +kubernetes.io/service-account-token '
expect 'delete removes legacy-monitor-token' "$(kubectl -n starfleet delete secret legacy-monitor-token)" 'secret "legacy-monitor-token" deleted'
expect_equal 'the list no longer holds legacy-monitor-token' "$(kubectl get secrets --all-namespaces --field-selector type=kubernetes.io/service-account-token 2>&1 | grep -c legacy-monitor-token || true)" 0

# Guided Practice: the fix and its checks. The guide gives no YAML: the reader
# writes the ServiceAccount monitor and changes the Deployment. The objects
# below are the ones the guide describes. The default ServiceAccount, the
# RoleBinding and the Secret were handled by the third page above.
cat >serviceaccount-monitor.yaml <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: monitor
  namespace: starfleet
automountServiceAccountToken: false
YAML
kubectl apply -f serviceaccount-monitor.yaml
kubectl -n starfleet patch deployment monitor --type=merge -p '{"spec":{"template":{"spec":{"serviceAccountName":"monitor","automountServiceAccountToken":false}}}}'
page=playground/docs/overview.md
kubectl -n starfleet rollout status deployment/monitor --timeout=180s
# The old pod runs sleep, which ignores SIGTERM, so it stays Terminating for
# up to 30 seconds. Wait until it is gone, so exec reaches the new pod.
wait_for_one_monitor_pod() {
  local attempt
  for attempt in $(seq 1 45); do
    [[ "$(kubectl -n starfleet get pods -l app=monitor --no-headers 2>/dev/null | wc -l | tr -d ' ')" == 1 ]] && return 0
    sleep 2
  done
  printf 'the old monitor pod did not go away\n' >&2
  exit 1
}
wait_for_one_monitor_pod
expect_equal 'guide: monitor has no token' "$(kubectl -n starfleet exec deploy/monitor -- sh -c "test -e $token_path && echo mounted || echo absent")" absent
expect_equal 'guide: default may not list pods' "$(can_i list pods --as="$default_account" -n starfleet)" no
expect 'guide: no token Secret is left in starfleet' "$(kubectl -n starfleet get secrets --field-selector type=kubernetes.io/service-account-token 2>&1)" 'No resources found in starfleet namespace.'

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
