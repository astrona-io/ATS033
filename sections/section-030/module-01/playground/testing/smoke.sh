#!/usr/bin/env bash
# Runs the commands that the playground guide and the module pages teach
# against the live playground, and fails when one of them does not give the
# result the page shows or describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster, so the `export KUBECONFIG=...` lines of the pages are not
# repeated here.
set -euo pipefail
playground=ats-033-playground-030-01
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
# The pages name the node astro-ats-033-playground-030-01-control-plane and
# run node commands with `podman exec "$node_name"`; here the container engine
# and the cluster name come from the shared guard settings.
node_name="$cluster-control-plane"
run_on_node() { "$engine" exec "$node_name" "$@"; }

# Write the first YAML block after "Save this as `<file>`" on a page into the
# work directory.
save_file_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'[Ss]ave this as `' + re.escape(name) + r'`.*?```yaml\n(.*?)```', text, re.S)
if not match:
    sys.exit('no YAML block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

# Write the YAML block from a page and apply it.
save_from_page() {
  save_file_from_page "$1" "$2"
  kubectl apply -f "$2"
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

# Run a command that the page expects to fail. Print its output and the word
# "failed" when it exits non-zero, or "succeeded" when it exits zero.
run_expecting_failure() {
  local output
  if output="$("$@" 2>&1)"; then
    printf '%s\nsucceeded\n' "$output"
  else
    printf '%s\nfailed\n' "$output"
  fi
}

# A request that the page says times out: it fails, and not with a refusal.
expect_timeout() {
  local result
  result="$(run_expecting_failure "${@:2}")"
  printf '%s\n' "$result"
  expect "$1 fails" "$result" failed
  expect "$1 times out" "$result" 'timed out'
}

probe_url=http://probe.starfleet.svc.cluster.local

# Guided Practice: Bind A Host-Network Service To Loopback
page=playground/docs/overview.md
expect_equal 'guide: the private context is selected' "$(kubectl config current-context)" "$context"
pods="$(kubectl -n starfleet get pods -o wide)"
printf '%s\n' "$pods"
expect_equal 'guide: two probe replicas are Running' "$(printf '%s\n' "$pods" | grep -cE '^probe-[a-z0-9-]+ +1/1 +Running ' || true)" 2
expect_match 'guide: the shuttle pod is Running' "$pods" '^shuttle +1/1 +Running '
nodes="$(kubectl get nodes -o wide)"
printf '%s\n' "$nodes"
expect_match 'guide: the control-plane node is Ready' "$nodes" "^$node_name +Ready "
expect_match 'guide: the worker node is Ready' "$nodes" "^$cluster-worker +Ready "
expect 'guide: apply creates node-local-server' "$(save_from_page "$page" pod-node-local-server.yaml)" 'pod/node-local-server created'
kubectl -n starfleet wait --for=condition=Ready pod/node-local-server --timeout=180s
expect_equal 'guide: a loopback request inside node-local-server returns 200' "$(kubectl -n starfleet exec node-local-server -- python -c 'import urllib.request; print(urllib.request.urlopen('"'"'http://127.0.0.1:19090/'"'"',timeout=3).status)')" 200

# Listeners And Bind Addresses
page=course-01-listeners-and-bind-addresses.md
NODE_IP="$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
echo "$NODE_IP"
expect_match 'the node InternalIP is an IPv4 address' "$NODE_IP" '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
save_from_page "$page" pod-exposed-server.yaml
kubectl -n starfleet wait --for=condition=Ready pod/exposed-server --timeout=180s
listeners="$(run_on_node ss -tln)"
printf '%s\n' "$listeners"
expect_match 'port 19091 listens on a wildcard address' "$listeners" '(0\.0\.0\.0|\*|\[::\]):19091 '
expect 'a request from shuttle to the node address prints a directory listing' "$(kubectl -n starfleet exec shuttle -- wget -qO- -T 3 "http://$NODE_IP:19091/")" 'Directory listing'
# The guide already created node-local-server with the same fields, so this
# apply leaves it unchanged.
save_from_page "$page" pod-node-local-server.yaml
kubectl -n starfleet wait --for=condition=Ready pod/node-local-server --timeout=180s
listeners="$(run_on_node ss -tln)"
printf '%s\n' "$listeners"
expect_match 'port 19090 listens on 127.0.0.1 only' "$listeners" ' 127\.0\.0\.1:19090 '
expect_equal 'port 19090 has no other listener' "$(printf '%s\n' "$listeners" | grep ':19090 ' | grep -vc ' 127\.0\.0\.1:19090 ' || true)" 0
refused="$(run_expecting_failure kubectl -n starfleet exec shuttle -- wget -qO- -T 3 "http://$NODE_IP:19090/")"
printf '%s\n' "$refused"
expect 'the request from shuttle to port 19090 fails' "$refused" failed
expect 'the request from shuttle to port 19090 is refused' "$refused" 'Connection refused'
expect_equal 'the loopback request inside the server pod prints 200' "$(kubectl -n starfleet exec node-local-server -- python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:19090/', timeout=3).status)")" 200

# Host Firewalls With iptables And ufw
page=course-02-host-firewalls-with-iptables-and-ufw.md
input_rules="$(run_on_node iptables --list INPUT --numeric --line-numbers)"
printf '%s\n' "$input_rules"
expect_match 'the INPUT chain shows its policy' "$input_rules" '^Chain INPUT \(policy (ACCEPT|DROP)'
expect 'the Kubernetes rules jump to KUBE- chains' "$input_rules" 'KUBE-'
# exposed-server exists from the previous page with the same fields.
save_from_page "$page" pod-exposed-server.yaml
kubectl -n starfleet wait --for=condition=Ready pod/exposed-server --timeout=180s
NODE_IP="$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
expect 'before any rule, the request prints a directory listing' "$(kubectl -n starfleet exec shuttle -- wget -qO- -T 3 "http://$NODE_IP:19091/")" 'Directory listing'
run_on_node iptables --insert INPUT 1 --protocol tcp --dport 19091 --jump DROP
input_rules="$(run_on_node iptables --list INPUT --numeric --line-numbers)"
printf '%s\n' "$input_rules"
expect_match 'rule 1 drops TCP port 19091' "$input_rules" '^1 +DROP +(tcp|6) .*dpt:19091'
expect_timeout 'with the DROP rule, the request from shuttle' kubectl -n starfleet exec shuttle -- wget -qO- -T 3 "http://$NODE_IP:19091/"
run_on_node iptables --delete INPUT 1
expect 'after the rule is deleted, the request works again' "$(kubectl -n starfleet exec shuttle -- wget -qO- -T 3 "http://$NODE_IP:19091/")" 'Directory listing'

# NodePorts, Control-Plane Ports And API Access
# This page runs before the NetworkPolicy page: its NodePort request must
# reach the probe pods, and the page says that an active policy on the probe
# pods can make it time out.
page=course-04-nodeports-control-plane-ports-and-api-access.md
services="$(kubectl get services -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,PORTS:.spec.ports[*].nodePort)"
printf '%s\n' "$services"
expect_match 'the inventory has the column titles' "$services" '^NAMESPACE +NAME +TYPE +PORTS$'
expect_equal 'every Service is of type ClusterIP' "$(printf '%s\n' "$services" | sed 1d | grep -cv ' ClusterIP ' || true)" 0
expect_equal 'every PORTS value is <none>' "$(printf '%s\n' "$services" | sed 1d | grep -cv '<none>$' || true)" 0
expect 'apply creates probe-nodeport' "$(save_from_page "$page" service-probe-nodeport.yaml)" 'service/probe-nodeport created'
NODE_IP="$(kubectl get node "$cluster-control-plane" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
expect_match 'drifter reaches the probe through the node port' "$(kubectl -n outpost exec drifter -- wget -qO- -T 3 "http://$NODE_IP:30080/")" '^version=v1'
expect 'deleting probe-nodeport succeeds' "$(kubectl -n starfleet delete service probe-nodeport)" 'service "probe-nodeport" deleted'
API_SERVER="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
anonymous="$(curl --insecure --silent --max-time 5 "$API_SERVER/api/v1/namespaces" || true)"
printf '%s\n' "$anonymous"
expect 'the API server refuses system:anonymous' "$anonymous" 'system:anonymous'
expect 'the answer is a Failure status, not a namespace list' "$anonymous" '"status": "Failure"'

# NetworkPolicy For Pod Traffic
page=course-03-networkpolicy-for-pod-traffic.md
expect_match 'before any policy, shuttle gets version=v1' "$(kubectl -n starfleet exec shuttle -- wget -qO- -T 3 "$probe_url")" '^version=v1'
expect_match 'before any policy, drifter gets version=v1' "$(kubectl -n outpost exec drifter -- wget -qO- -T 3 "$probe_url")" '^version=v1'
expect 'apply creates default-deny-ingress' "$(save_from_page "$page" networkpolicy-default-deny-ingress.yaml)" 'networkpolicy.networking.k8s.io/default-deny-ingress created'
# The CNI plugin needs a moment to program the policy; a reader types the next
# command by hand.
sleep 5
expect_timeout 'with default deny, the request from shuttle' kubectl -n starfleet exec shuttle -- wget -qO- -T 3 "$probe_url"
expect_timeout 'with default deny, the request from drifter' kubectl -n outpost exec drifter -- wget -qO- -T 3 "$probe_url"
expect 'apply creates allow-shuttle-to-probe' "$(save_from_page "$page" networkpolicy-allow-shuttle-to-probe.yaml)" 'networkpolicy.networking.k8s.io/allow-shuttle-to-probe created'
sleep 5
expect_match 'with the allow policy, shuttle gets version=v1 again' "$(kubectl -n starfleet exec shuttle -- wget -qO- -T 3 "$probe_url")" '^version=v1'
expect_timeout 'with the allow policy, the request from drifter' kubectl -n outpost exec drifter -- wget -qO- -T 3 "$probe_url"
policies="$(kubectl -n starfleet get networkpolicy)"
printf '%s\n' "$policies"
expect_match 'the list shows default-deny-ingress' "$policies" '^default-deny-ingress '
expect_match 'the list shows allow-shuttle-to-probe' "$policies" '^allow-shuttle-to-probe +app=probe '

if [[ "$failures" -gt 0 ]]; then
  printf 'FAIL: %s of %s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi
printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
