#!/usr/bin/env bash
# Runs the commands that the module pages teach inside the playground VM and
# fails when one of them does not give the result the page describes.
# scripts/ci/test-playground.sh copies the pages and this folder into the VM
# and runs the script there as the student user. The VM is the only node, so
# node commands use sudo directly.
set -euo pipefail
cluster="astro-ats-033-playground-030-03"
if [[ "$(kubectl config current-context)" != "${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@$cluster}" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

# The cluster is ready and the workloads of the pages run.
kubectl -n starfleet rollout status deployment/probe --timeout=60s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=60s
kubectl get --raw=/readyz >/dev/null

module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
kubelet_config=/var/lib/kubelet/config.yaml

# Print the text block that follows the first code block containing the given
# command on a page: the output the page shows for that command.
output_from_page() {
  python3 - "$module_directory/$1" "$2" <<'PY'
import re, sys
page, command = sys.argv[1:]
text = open(page).read()
match = re.search(r'```sh\n[^`]*' + re.escape(command) + r'[^`]*```\s*```(?:text|json)\n(.*?)```', text, re.S)
if not match:
    sys.exit('no output block after ' + command + ' in ' + page)
print(match.group(1), end='')
PY
}

# Make ss output comparable: process numbers and file descriptors differ on
# every VM, the column widths follow the longest address, and the line order
# is not fixed.
normalize_listeners() {
  sed -E 's/pid=[0-9]+,fd=[0-9]+/pid,fd/g; s/ +/ /g; s/ $//' | sort
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

kubelet_status() {
  curl -sk --max-time 5 -o /dev/null -w '%{http_code}' https://127.0.0.1:10250/pods || true
}

# The pages say "wait a few seconds for the kubelet to start". Wait until the
# node is Ready and the kubelet API answers with the given status, at most
# about 2 minutes.
wait_for_kubelet() {
  local attempt
  for attempt in $(seq 1 40); do
    if [[ "$(kubelet_status)" == "$1" ]] &&
      [[ "$(kubectl get node "$cluster" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" == True ]]; then
      return 0
    fi
    sleep 3
  done
  printf 'FAIL: the kubelet did not come back with status %s\n' "$1" >&2
  sudo systemctl status kubelet --no-pager >&2 || true
  exit 1
}

# Guided Practice: Close The Kubelet API To Anonymous Callers
# The guide makes the same kubelet change as the kubelet part, so only its
# starting state and its inspection run first; its change runs at the end.
guide=playground/docs/overview.md
expect_equal 'guide: the playground context is selected' "$(kubectl config current-context)" "kubernetes-admin@$cluster"
expect_equal 'guide: the probe Deployment has 2 ready replicas' "$(kubectl -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}')" 2
expect_equal 'guide: the probe Service exists' "$(kubectl -n starfleet get service probe -o jsonpath='{.metadata.name}')" probe
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=60s
expect_match 'guide: the probe Service answers shuttle' "$(kubectl -n starfleet exec shuttle -- wget -qO- -T 5 http://probe)" '^version=v1'
authentication_block="$(sudo grep -A12 '^authentication:' "$kubelet_config")"
printf '%s\n' "$authentication_block"
expect 'guide: anonymous access is enabled' "$authentication_block" $'  anonymous:\n    enabled: true'
expect 'guide: authorization mode is AlwaysAllow' "$authentication_block" '  mode: AlwaysAllow'
expect_equal 'guide: the anonymous request returns 200' "$(kubelet_status)" 200

# Control-Plane Ports And Listeners
page=course-01-control-plane-ports-and-listeners.md
expect_equal 'kubectl uses the playground cluster' "$(kubectl config current-context)" "$(output_from_page "$page" 'kubectl config current-context')"
listeners="$(sudo ss -tlnp)"
printf '%s\n' "$listeners"
# The full listing also has ports that change on every boot (containerd) and
# DNS listeners of the VM image, so only the page's Kubernetes and SSH lines
# are compared.
for port_line in '127.0.0.1:2381 ' '127.0.0.1:10248 ' '127.0.0.1:10249 ' '0.0.0.0:22 ' '\[::\]:22 ' '\*:10256 '; do
  expected_line="$(output_from_page "$page" 'sudo ss -tlnp' | grep -E " $port_line" | normalize_listeners)"
  expect "the listener line for ${port_line% } matches the page" "$(printf '%s\n' "$listeners" | normalize_listeners)" "$expected_line"
done
filtered="$(sudo ss -tlnp | grep -E ':(6443|10250|2379|2380|10257|10259) ')"
printf '%s\n' "$filtered"
expect_equal 'the six control-plane listeners match the page' "$(printf '%s\n' "$filtered" | normalize_listeners)" "$(output_from_page "$page" "sudo ss -tlnp | grep -E ':(6443" | normalize_listeners)"
expect_equal 'the controller manager and scheduler bind to loopback' \
  "$(sudo grep -H 'bind-address' /etc/kubernetes/manifests/kube-controller-manager.yaml /etc/kubernetes/manifests/kube-scheduler.yaml)" \
  "$(output_from_page "$page" "sudo grep -H 'bind-address'")"

# API Server Authentication And Authorization
page=course-02-api-server-authentication-and-authorization.md
expect_equal 'the API server flags match the page' \
  "$(sudo grep -E 'anonymous-auth|authorization-mode|bind-address|secure-port|client-ca-file' /etc/kubernetes/manifests/kube-apiserver.yaml)" \
  "$(output_from_page "$page" "sudo grep -E 'anonymous-auth")"
API_SERVER="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
version_page="$(output_from_page "$page" 'API_SERVER="$(kubectl config view')"
expect_equal 'the API server address matches the page' "$API_SERVER" "$(printf '%s\n' "$version_page" | sed -n 1p)"
version="$(curl --insecure --silent --max-time 5 "$API_SERVER/version")"
printf '%s\n' "$version"
# The build date, commit and platform depend on the release and the VM.
for version_field in major minor gitVersion gitTreeState; do
  expect "the anonymous /version reply has the page's $version_field" "$version" "$(printf '%s\n' "$version_page" | grep "\"$version_field\":")"
done
expect_equal 'the anonymous namespace list is forbidden as the page shows' \
  "$(curl --insecure --silent --max-time 5 "$API_SERVER/api/v1/namespaces")" \
  "$(output_from_page "$page" '"$API_SERVER/api/v1/namespaces"')"
if impersonated="$(kubectl get namespaces --as=system:anonymous 2>&1)"; then
  printf 'FAIL: system:anonymous may list namespaces\n%s\n' "$impersonated" >&2
  failures=$((failures + 1))
fi
expect 'kubectl as system:anonymous is forbidden' "$impersonated" 'Error from server (Forbidden): namespaces is forbidden: User "system:anonymous" cannot list resource "namespaces" in API group "" at the cluster scope'
expect 'kubectl as system:anonymous reads /version' "$(kubectl get --raw /version --as=system:anonymous)" "$(printf '%s\n' "$version_page" | grep '"gitVersion":')"
if can_i="$(kubectl auth can-i list namespaces --as=system:anonymous 2>&1)"; then
  printf 'FAIL: kubectl auth can-i worked for system:anonymous\n%s\n' "$can_i" >&2
  failures=$((failures + 1))
fi
expect 'kubectl auth can-i fails on the SelfSubjectAccessReview' "$can_i" 'Error from server (Forbidden): selfsubjectaccessreviews.authorization.k8s.io is forbidden: User "system:anonymous" cannot create resource "selfsubjectaccessreviews" in API group "authorization.k8s.io" at the cluster scope'
binding="$(kubectl get clusterrolebinding system:public-info-viewer -o wide)"
printf '%s\n' "$binding"
expect_match 'the public-info-viewer binding names both groups' "$binding" '^system:public-info-viewer +ClusterRole/system:public-info-viewer +[0-9a-z]+ +system:authenticated, system:unauthenticated *$'

# etcd Client Access
# This part only reads, so it runs before the kubelet change.
page=course-04-etcd-client-access.md
expect_equal 'the etcd flags match the page' \
  "$(sudo grep -E 'listen-client-urls|listen-peer-urls|client-cert-auth|trusted-ca-file|data-dir' /etc/kubernetes/manifests/etcd.yaml)" \
  "$(output_from_page "$page" "sudo grep -E 'listen-client-urls")"
etcd_page="$(output_from_page "$page" "sudo ss -tlnp | grep -E ':(2379")"
expect_equal 'the etcd listeners match the page' \
  "$(sudo ss -tlnp | grep -E ':(2379|2380|2381) ' | normalize_listeners)" \
  "$(printf '%s\n' "$etcd_page" | grep '^LISTEN' | normalize_listeners)"
expect_equal 'the etcd data directory mode matches the page' "$(sudo stat -c '%a %U' /var/lib/etcd)" "$(printf '%s\n' "$etcd_page" | tail -1)"
expect_equal 'curl without the etcd CA fails with status 60' \
  "$(curl -s --max-time 5 https://127.0.0.1:2379/health; echo "rc=$?")" \
  "$(output_from_page "$page" 'curl -s --max-time 5 https://127.0.0.1:2379/health')"
# The page describes, without a command block, the same request with -k.
expect_equal 'curl -k without a client certificate fails with status 56' \
  "$(curl -sk --max-time 5 https://127.0.0.1:2379/health; echo "rc=$?")" 'rc=56'
expect_equal 'the health check client certificate gets the health reply' \
  "$(sudo curl -s --max-time 5 --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/healthcheck-client.crt --key /etc/kubernetes/pki/etcd/healthcheck-client.key https://127.0.0.1:2379/health)" \
  "$(output_from_page "$page" 'sudo curl -s --max-time 5 --cacert')"

# Kubelet API Authentication And Authorization
page=course-03-kubelet-api-authentication-and-authorization.md
expect_equal 'the kubelet authentication block matches the page' \
  "$(sudo grep -A12 '^authentication:' "$kubelet_config")" \
  "$(output_from_page "$page" "sudo grep -A12 '^authentication:'")"
expect_equal 'the anonymous kubelet request prints 200' "$(curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:10250/pods)" 200
expect 'the anonymous kubelet request lists the pods' "$(curl -sk https://127.0.0.1:10250/pods | head -c 300)" '{"kind":"PodList","apiVersion":"v1","metadata":{},"items":[{"metadata":{"name":"'
expect_equal 'the three change commands print nothing' "$(
  sudo sed -i '/^authentication:/,/^  webhook:/ s/enabled: true/enabled: false/' /var/lib/kubelet/config.yaml
  sudo sed -i 's/^  mode: AlwaysAllow$/  mode: Webhook/' /var/lib/kubelet/config.yaml
  sudo systemctl restart kubelet
)" ''
wait_for_kubelet 401
after_page="$(output_from_page "$page" 'kubectl get nodes')"
nodes="$(kubectl get nodes)"
printf '%s\n' "$nodes"
expect_match 'the node is Ready again' "$nodes" "^$cluster +Ready +control-plane +[0-9a-z]+ +$(printf '%s\n' "$after_page" | sed -n 2p | awk '{print $5}')$"
expect_equal 'the changed authentication block matches the page' \
  "$(sudo grep -A12 '^authentication:' "$kubelet_config")" \
  "$(printf '%s\n' "$after_page" | sed -n '3,15p')"
expect_equal 'the anonymous kubelet request now prints 401' "$(curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:10250/pods)" "$(printf '%s\n' "$after_page" | tail -1)"
# The page says the API server still reaches the kubelet; kubectl logs goes
# through the API server to the kubelet API.
if kubectl -n starfleet logs deployment/probe --tail=1 >/dev/null; then logs_status=ok; else logs_status=failed; fi
expect_equal 'the API server still reaches the kubelet for logs' "$logs_status" ok

# The guide's change: the kubelet already has the result, so the two sed
# commands change nothing and the restart brings back the same state.
page=$guide
sudo sed -i '/^authentication:/,/^  webhook:/ s/enabled: true/enabled: false/' /var/lib/kubelet/config.yaml
sudo sed -i 's/^  mode: AlwaysAllow$/  mode: Webhook/' /var/lib/kubelet/config.yaml
sudo systemctl restart kubelet
wait_for_kubelet 401
expect_match 'guide: the node is Ready' "$(kubectl get nodes)" "^$cluster +Ready "
authentication_block="$(sudo grep -A12 '^authentication:' "$kubelet_config")"
expect 'guide: anonymous access is disabled' "$authentication_block" $'  anonymous:\n    enabled: false'
expect 'guide: the webhook authentication stays enabled' "$authentication_block" $'  webhook:\n    cacheTTL: 0s\n    enabled: true'
expect 'guide: authorization mode is Webhook' "$authentication_block" '  mode: Webhook'
expect_equal 'guide: the anonymous request returns 401' "$(curl -sk -o /dev/null -w '%{http_code}' https://127.0.0.1:10250/pods)" 401

if [[ "$failures" -gt 0 ]]; then
  printf 'FAIL: %s of %s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi
printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
