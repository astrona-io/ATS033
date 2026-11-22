#!/usr/bin/env bash
# Runs the commands that the playground guide and the module pages teach
# against the live playground, and fails when one of them does not give the
# result the page shows or describes.
# scripts/ci/test-playground.sh runs it on the host with KUBECONFIG set to the
# playground cluster, so the `export KUBECONFIG=...` lines of the pages are not
# repeated here.
set -euo pipefail
playground=ats-033-playground-030-02
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

# The pages set node_name and worker_name to the two node containers of this
# playground; the names come from the cluster name of the shared guard settings.
# No page of this module runs a node command, so "$engine" is only part of the
# shared guard settings.
node_name="$cluster-control-plane"
worker_name="$cluster-worker"

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

node_address() {
  kubectl get node "$1" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}'
}

# Guided Practice: Close A NodePort And Narrow A LoadBalancer
# The guide changes probe-admin and probe-edge, the two Services that the
# reading pages change step by step, so only its description of the starting
# state and its inventory run first. Its changes run after the pages.
guide=playground/docs/overview.md
expect_equal 'guide: the private context is selected' "$(kubectl config current-context)" "$context"
expect_equal 'guide: the probe Deployment has two ready replicas' "$(kubectl -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}')" 2
expect_equal 'guide: the probe Service is of type ClusterIP' "$(kubectl -n starfleet get service probe -o jsonpath='{.spec.type}')" ClusterIP
inventory_command=(kubectl get services -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,NODEPORT:.spec.ports[*].nodePort)
inventory="$("${inventory_command[@]}")"
printf '%s\n' "$inventory"
expect_match 'guide: probe-admin is a NodePort on 30090' "$inventory" '^starfleet +probe-admin +NodePort +30090$'
expect_match 'guide: probe-edge is a LoadBalancer' "$inventory" '^starfleet +probe-edge +LoadBalancer +3[0-9]{4}$'
expect_equal 'guide: shuttle runs BusyBox' "$(kubectl -n starfleet get pod shuttle -o jsonpath='{.spec.containers[0].image}')" docker.io/library/busybox:1.37.0
expect_equal 'guide: drifter runs BusyBox' "$(kubectl -n outpost get pod drifter -o jsonpath='{.spec.containers[0].image}')" docker.io/library/busybox:1.37.0

# Service Types And What They Open
page=course-01-service-types-and-what-they-open.md
inventory="$("${inventory_command[@]}")"
printf '%s\n' "$inventory"
expect_match 'probe-admin is a NodePort on port 30090' "$inventory" '^starfleet +probe-admin +NodePort +30090$'
expect_match 'probe-edge is a LoadBalancer with an allocated node port' "$inventory" '^starfleet +probe-edge +LoadBalancer +3[0-9]{4}$'
expect_match 'the kubernetes Service is ClusterIP' "$inventory" '^default +kubernetes +ClusterIP +<none>$'
expect_match 'the kube-dns Service is ClusterIP' "$inventory" '^kube-system +kube-dns +ClusterIP +<none>'
CONTROL_IP="$(node_address "$node_name")"
WORKER_IP="$(node_address "$worker_name")"
expect_match 'drifter reaches the node port on the worker' "$(kubectl -n outpost exec drifter -- wget -qO- -T 3 "http://$WORKER_IP:30090/")" '^version=v1'
expect_match 'drifter reaches the node port on the control plane too' "$(kubectl -n outpost exec drifter -- wget -qO- -T 3 "http://$CONTROL_IP:30090/")" '^version=v1'
expect_equal 'every probe pod runs on the worker node' "$(kubectl -n starfleet get pods -l app=probe -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u)" "$worker_name"
expect_equal 'drifter is not on the control-plane node' "$(kubectl -n outpost get pod drifter -o jsonpath='{.spec.nodeName}')" "$worker_name"
expect 'apply changes probe-admin' "$(save_from_page "$page" service-probe-admin.yaml)" 'service/probe-admin configured'
admin="$(kubectl -n starfleet get service probe-admin)"
printf '%s\n' "$admin"
expect_match 'probe-admin is now ClusterIP with port 80 only' "$admin" '^probe-admin +ClusterIP +[0-9.]+ +<none> +80/TCP '
closed="$(run_expecting_failure kubectl -n outpost exec drifter -- wget -qO- -T 3 "http://$WORKER_IP:30090/")"
printf '%s\n' "$closed"
expect 'the request to the released node port fails' "$closed" failed
expect 'wget prints an error' "$closed" 'wget: '
expect_match 'pods still reach probe-admin by its name' "$(kubectl -n starfleet exec shuttle -- wget -qO- -T 3 http://probe-admin.starfleet)" '^version=v1'

# Narrowing NodePorts And Load Balancers
page=course-02-narrowing-nodeports-and-load-balancers.md
edge_fields="$(kubectl -n starfleet get service probe-edge -o jsonpath='{.spec.externalTrafficPolicy}{"\n"}{.spec.loadBalancerSourceRanges}{"\n"}{.spec.ports[0].nodePort}{"\n"}{.status.loadBalancer}{"\n"}')"
printf '%s\n' "$edge_fields"
expect_equal 'line 1 is Cluster' "$(printf '%s\n' "$edge_fields" | sed -n 1p)" Cluster
expect_equal 'line 2 is empty' "$(printf '%s\n' "$edge_fields" | sed -n 2p)" ''
expect_match 'line 3 is the allocated node port' "$(printf '%s\n' "$edge_fields" | sed -n 3p)" '^3[0-9]{4}$'
# An empty status.loadBalancer object prints as {} with jsonpath.
expect_match 'line 4 has no load balancer address' "$(printf '%s\n' "$edge_fields" | sed -n 4p)" '^(\{\})?$'
expect 'apply changes probe-edge' "$(save_from_page "$page" service-probe-edge.yaml)" 'service/probe-edge configured'
EDGE_PORT="$(kubectl -n starfleet get service probe-edge -o jsonpath='{.spec.ports[0].nodePort}')"
CONTROL_IP="$(node_address "$node_name")"
WORKER_IP="$(node_address "$worker_name")"
expect_match 'under Local, the worker address answers' "$(kubectl -n outpost exec drifter -- wget -qO- -T 3 "http://$WORKER_IP:$EDGE_PORT/")" '^version=v1'
# kube-proxy writes the new rules a few seconds after the apply, so ask again
# for up to 60 seconds before the control-plane request is expected to fail.
for attempt in $(seq 1 20); do
  dropped="$(run_expecting_failure kubectl -n outpost exec drifter -- wget -qO- -T 3 "http://$CONTROL_IP:$EDGE_PORT/")"
  [[ "$dropped" == *failed ]] && break
  sleep 3
done
printf '%s\n' "$dropped"
expect 'under Local, the control-plane request fails' "$dropped" failed
expect 'under Local, the control-plane request times out' "$dropped" 'timed out'

# Ingress As The Single Entry Point
page=course-03-ingress-and-finding-exposed-services.md
expect 'apply creates the Ingress probe' "$(save_from_page "$page" ingress-probe.yaml)" 'ingress.networking.k8s.io/probe created'
ingress="$(kubectl -n starfleet get ingress probe)"
printf '%s\n' "$ingress"
expect_match 'the Ingress has no ADDRESS' "$ingress" '^probe +nginx +probe\.example\.test +80 '
expect 'no ingress class exists' "$(kubectl get ingressclass 2>&1)" 'No resources found'
audit="$(kubectl get services -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,EXTERNAL-IPS:.spec.externalIPs,NODEPORT:.spec.ports[*].nodePort)"
printf '%s\n' "$audit"
expect_match 'the audit has the EXTERNAL-IPS column' "$audit" '^NAMESPACE +NAME +TYPE +EXTERNAL-IPS +NODEPORT$'
expect_equal 'no Service has externalIPs' "$(printf '%s\n' "$audit" | sed 1d | awk '$4 != "<none>"' | wc -l | tr -d ' ')" 0
expect_match 'probe-edge is the only Service with a node port' "$(printf '%s\n' "$audit" | sed 1d | awk '$5 != "<none>" {print $2}')" '^probe-edge$'
expect_match 'the ingress list shows probe' "$(kubectl get ingress -A)" '^starfleet +probe +nginx +probe\.example\.test '
host_network="$(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTNETWORK:.spec.hostNetwork)"
printf '%s\n' "$host_network"
expect_match 'kube-proxy pods share the node network' "$host_network" '^kube-system +kube-proxy-[a-z0-9]+ +true$'
expect_match 'shuttle does not use the node network' "$host_network" '^starfleet +shuttle +<none>$'
expect 'deleting the Ingress succeeds' "$(kubectl -n starfleet delete ingress probe)" 'ingress.networking.k8s.io "probe" deleted'

# The guide's changes: both Services already have the result from the pages,
# so the applies leave them unchanged, and the checks still hold.
page=$guide
expect 'guide: apply leaves probe-admin unchanged' "$(save_from_page "$page" service-probe-admin.yaml)" 'service/probe-admin unchanged'
expect 'guide: apply leaves probe-edge unchanged' "$(save_from_page "$page" service-probe-edge.yaml)" 'service/probe-edge unchanged'
services="$(kubectl -n starfleet get services probe-admin probe-edge)"
printf '%s\n' "$services"
expect_match 'guide: probe-admin is ClusterIP' "$services" '^probe-admin +ClusterIP +[0-9.]+ +<none> +80/TCP '
expect_match 'guide: the EXTERNAL-IP of probe-edge stays <pending>' "$services" '^probe-edge +LoadBalancer +[0-9.]+ +<pending> +80:3[0-9]{4}/TCP '
expect_equal 'guide: probe-edge accepts only 203.0.113.0/24' "$(kubectl -n starfleet get service probe-edge -o jsonpath='{.spec.loadBalancerSourceRanges[*]}')" 203.0.113.0/24
expect_equal 'guide: probe-edge uses externalTrafficPolicy Local' "$(kubectl -n starfleet get service probe-edge -o jsonpath='{.spec.externalTrafficPolicy}')" Local
NODE_IP="$(node_address "$node_name")"
closed="$(run_expecting_failure kubectl -n outpost exec drifter -- wget -qO- -T 3 "http://$NODE_IP:30090/")"
printf '%s\n' "$closed"
expect 'guide: the request to port 30090 fails' "$closed" failed

if [[ "$failures" -gt 0 ]]; then
  printf 'FAIL: %s of %s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi
printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
