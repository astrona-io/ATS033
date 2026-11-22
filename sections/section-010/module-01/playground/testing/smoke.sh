#!/usr/bin/env bash
# Runs the commands that the module pages and the playground guide teach
# inside the playground VM, and fails when one of them does not give the
# result the page shows or describes.
# scripts/ci/test-playground.sh copies the module pages, docs/ and testing/
# into the VM and runs this file there as the student user, the user the
# learner logs in as. The VM is the only node, so node commands use sudo
# directly. The `astrona ssh` line of each page is the login itself and is not
# repeated here.
set -euo pipefail
cluster="astro-ats-033-playground-010-01"
if [[ "$(kubectl config current-context)" != "${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@$cluster}" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

# The cluster is ready and the workloads of the pages run.
kubectl -n starfleet rollout status deployment/probe --timeout=60s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=60s
kubectl get --raw=/readyz >/dev/null

module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
# Files that the pages save land in the current directory, as for the reader.
cd "$work_directory"

# Write the code block that follows "Save this as `<file>`:" on a page into the
# work directory.
save_file_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'Save this as `' + re.escape(name) + r'`:\s*```[a-z]*\n(.*?)```', text, re.S)
if not match:
    sys.exit('no code block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

# Print the text block that directly follows the first sh block on a page that
# contains the given command: the output the page shows for that block.
output_from_page() {
  python3 - "$module_directory/$1" "$2" <<'PY'
import re, sys
page, command = sys.argv[1:]
text = open(page).read()
for block in re.finditer(r'```sh\n((?:(?!```).)*)```\s*```text\n(.*?)```', text, re.S):
    if command in block.group(1):
        print(block.group(2), end='')
        break
else:
    sys.exit('no output block after ' + command + ' in ' + page)
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

# The node checks that close the guide and the service page.
check_node_works() {
  local label=$1 nodes
  expect_equal "$label: kubelet and containerd are active" "$(systemctl is-active kubelet.service containerd.service)" "$(printf 'active\nactive')"
  expect_equal "$label: the API server is ready" "$(kubectl get --raw=/readyz; echo)" ok
  nodes="$(kubectl get nodes)"
  printf '%s\n' "$nodes"
  expect_match "$label: the node is Ready" "$nodes" "^$cluster +Ready +control-plane +[0-9a-z]+ +v1\.35\.10$"
}

# Inventory Services And Listeners
page=course-01-inventory-services-and-listeners.md
expect_equal 'inventory: the context is the playground' "$(kubectl config current-context)" "kubernetes-admin@$cluster"
running="$(systemctl list-units --type=service --state=running --no-pager)"
printf '%s\n' "$running"
# The serial console unit and the user@ units depend on the machine and the
# logins, so only the units that the page names are checked.
for unit in containerd kubelet ModemManager ssh training-extra; do
  expect_match "inventory: $unit.service is running" "$running" "^  $unit\.service +loaded active running "
done
enabled="$(systemctl list-unit-files --type=service --state=enabled --no-pager)"
printf '%s\n' "$enabled"
for unit in containerd kubelet ModemManager training-extra; do
  expect_match "inventory: $unit.service is enabled" "$enabled" "^$unit\.service +enabled +enabled$"
done
expect 'inventory: the enabled list has 48 unit files' "$enabled" '48 unit files listed.'
status="$(systemctl status training-extra.service --no-pager)"
printf '%s\n' "$status"
expect 'inventory: status shows the unit file, enabled' "$status" 'Loaded: loaded (/etc/systemd/system/training-extra.service; enabled; preset: enabled)'
expect 'inventory: status shows active (running)' "$status" 'Active: active (running) since'
expect_match 'inventory: status shows the command line' "$status" '[0-9]+ /bin/sleep 3600$'
expect_equal 'inventory: systemctl cat shows the unit file' "$(systemctl cat training-extra.service)" "$(output_from_page "$page" 'systemctl cat training-extra.service')"
expect_equal 'inventory: only multi-user.target wants the service' "$(systemctl list-dependencies --reverse training-extra.service --no-pager)" "$(output_from_page "$page" 'list-dependencies --reverse training-extra.service')"
listeners="$(sudo ss -tlnp)"
printf '%s\n' "$listeners"
expect_match 'inventory: sshd listens on 0.0.0.0:22' "$listeners" '0\.0\.0\.0:22 .*"sshd"'
expect_match 'inventory: sshd listens on [::]:22' "$listeners" '\[::\]:22 .*"sshd"'
expect_match 'inventory: kube-apiserver listens on *:6443' "$listeners" '\*:6443 .*"kube-apiserver"'
expect_match 'inventory: the kubelet API listens on *:10250' "$listeners" '\*:10250 .*"kubelet"'
expect_match 'inventory: the kubelet health port is loopback only' "$listeners" '127\.0\.0\.1:10248 .*"kubelet"'
expect_match 'inventory: the scheduler is loopback only' "$listeners" '127\.0\.0\.1:10259 .*"kube-scheduler"'
expect_match 'inventory: the controller manager is loopback only' "$listeners" '127\.0\.0\.1:10257 .*"kube-controller"'
expect_match 'inventory: etcd listens on loopback 2379' "$listeners" '127\.0\.0\.1:2379 .*"etcd"'
expect_match 'inventory: etcd listens on the node address 2380' "$listeners" ':2380 .*"etcd"'
expect_match 'inventory: containerd listens on a loopback port' "$listeners" '127\.0\.0\.1:[0-9]+ .*"containerd"'

# Guided Practice: Disable An Unneeded Node Service
page=playground/docs/overview.md
expect_equal 'guide: the unit file and its reverse dependencies' "$(systemctl cat training-extra.service; systemctl list-dependencies --reverse training-extra.service --no-pager)" "$(output_from_page "$page" 'systemctl cat training-extra.service')"
disabled="$(sudo systemctl disable --now training-extra.service 2>&1)"
expect_equal 'guide: disable --now removes the boot link' "$disabled" 'Removed "/etc/systemd/system/multi-user.target.wants/training-extra.service".'
expect_equal 'guide: the service is inactive and disabled' "$(systemctl is-active training-extra.service || true; systemctl is-enabled training-extra.service || true)" "$(printf 'inactive\ndisabled')"
check_node_works guide

# The service page starts from the seeded state again: running and enabled.
# This step is not on a page; it only undoes the guide.
sudo systemctl enable --now training-extra.service

# Stop, Disable And Mask Services
page=course-02-stop-disable-and-mask-services.md
expect_equal 'services: the seeded service is active and enabled' "$(systemctl is-active training-extra.service; systemctl is-enabled training-extra.service)" "$(printf 'active\nenabled')"
sudo systemctl stop training-extra.service
expect_equal 'services: stop leaves the service enabled' "$(systemctl is-active training-extra.service || true; systemctl is-enabled training-extra.service)" "$(printf 'inactive\nenabled')"
disabled="$(sudo systemctl disable --now training-extra.service 2>&1)"
expect_equal 'services: disable --now removes the boot link' "$disabled" "$(output_from_page "$page" 'sudo systemctl disable --now training-extra.service')"
expect_equal 'services: the service is inactive and disabled' "$(systemctl is-active training-extra.service || true; systemctl is-enabled training-extra.service || true)" "$(printf 'inactive\ndisabled')"
expect_equal 'services: the ModemManager unit file and its reverse dependencies' "$(systemctl cat ModemManager.service; systemctl list-dependencies --reverse ModemManager.service --no-pager)" "$(output_from_page "$page" 'systemctl cat ModemManager.service')"
masked="$(sudo systemctl mask --now ModemManager.service 2>&1)"
expect_equal 'services: mask links the unit to /dev/null' "$masked" 'Created symlink /etc/systemd/system/ModemManager.service → /dev/null.'
expect_equal 'services: is-enabled answers masked' "$(systemctl is-enabled ModemManager.service || true)" masked
expect_equal 'services: systemd refuses to start a masked unit' "$(sudo systemctl start ModemManager.service 2>&1 || true)" 'Failed to start ModemManager.service: Unit ModemManager.service is masked.'
expect_match 'services: the mask is a link to /dev/null' "$(ls -l /etc/systemd/system/ModemManager.service)" '^lrwxrwxrwx 1 root root 9 .* /etc/systemd/system/ModemManager\.service -> /dev/null$'
expect_equal 'services: rm prints nothing' "$(sudo rm /etc/systemd/system/training-extra.service 2>&1)" ''
expect_equal 'services: daemon-reload prints nothing' "$(sudo systemctl daemon-reload 2>&1)" ''
expect_equal 'services: the deleted unit cannot be found' "$(systemctl status training-extra.service --no-pager 2>&1 || true)" 'Unit training-extra.service could not be found.'
check_node_works services

# Remove Packages And Keep The Node Working
page=course-03-remove-packages-and-keep-the-node-working.md
manual="$(apt-mark showmanual)"
for package in containerd kubeadm kubectl kubelet kubernetes-cni node-diag-tools; do
  expect_match "packages: $package is marked as manually installed" "$manual" "^$package$"
done
expect_equal 'packages: dpkg-query --list counts the lines the page shows' "$(dpkg-query --list | wc -l)" "$(output_from_page "$page" 'dpkg-query --list | wc -l')"
expect_equal 'packages: dpkg -S names the owners' "$(dpkg -S "$(readlink -f "$(command -v systemctl)")"; dpkg -S "$(readlink -f "$(command -v node-diag)")")" "$(printf 'systemd: /usr/bin/systemctl\nnode-diag-tools: /usr/bin/node-diag')"
local_sbin="$(ls -l /usr/local/sbin)"
printf '%s\n' "$local_sbin"
expect_match 'packages: /usr/local/sbin holds one file' "$local_sbin" '^total 4$'
expect_match 'packages: the helper is root-owned and executable' "$local_sbin" '^-rwxr-xr-x 1 root root [0-9]+ .* astrona-kubeadm-init$'
expect_equal 'packages: no package owns the helper' "$(dpkg -S /usr/local/sbin/astrona-kubeadm-init 2>&1 || true)" 'dpkg-query: no path found matching pattern /usr/local/sbin/astrona-kubeadm-init'
simulation="$(apt-get remove --simulate node-diag-tools 2>&1; apt-cache rdepends --installed node-diag-tools)"
printf '%s\n' "$simulation"
expect 'packages: the simulation says it is only a simulation' "$simulation" 'NOTE: This is only a simulation!'
expect 'packages: the simulation removes only node-diag-tools' "$simulation" "$(printf 'The following packages will be REMOVED:\n  node-diag-tools\n0 upgraded, 0 newly installed, 1 to remove and 0 not upgraded.\nRemv node-diag-tools [0.9.1]')"
expect_equal 'packages: one Remv line' "$(printf '%s\n' "$simulation" | grep -c '^Remv ')" 1
expect 'packages: no installed package depends on node-diag-tools' "$simulation" "$(printf 'node-diag-tools\nReverse Depends:')"
expect_equal 'packages: the reverse dependency list is empty' "$(printf '%s\n' "$simulation" | tail -n 1)" 'Reverse Depends:'
runtime_simulation="$(apt-get remove --simulate containerd 2>&1)"
expect_equal 'packages: the containerd simulation matches the page' "$runtime_simulation" "$(output_from_page "$page" 'apt-get remove --simulate containerd')"
purge="$(sudo apt-get purge --yes node-diag-tools 2>&1)"
printf '%s\n' "$purge"
expect 'packages: purge marks the package with a star' "$purge" "$(printf 'The following packages will be REMOVED:\n  node-diag-tools*')"
expect 'packages: purge removes node-diag-tools' "$purge" 'Removing node-diag-tools (0.9.1) ...'
expect_equal 'packages: the package is gone' "$(dpkg-query -W node-diag-tools 2>&1 || true)" 'dpkg-query: no packages found matching node-diag-tools'
expect 'packages: the autoremove would remove nothing' "$(apt-get autoremove --simulate 2>&1)" '0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.'
expect_equal 'packages: kubelet and containerd are active' "$(systemctl is-active kubelet.service containerd.service)" "$(printf 'active\nactive')"
expect_equal 'packages: the API server is ready' "$(kubectl get --raw=/readyz; echo)" ok
pods="$(kubectl -n starfleet get pods)"
printf '%s\n' "$pods"
expect_equal 'packages: two probe pods and shuttle run' "$(printf '%s\n' "$pods" | sed 1d | grep -cE '^(probe-[a-z0-9]+-[a-z0-9]+|shuttle) +1/1 +Running +0 ')" 3
expect_equal 'packages: no reboot is pending' "$(test -e /var/run/reboot-required && echo pending || echo none)" none

# Privileged Host Interfaces
page=course-04-privileged-host-interfaces.md
expect_match 'interfaces: the containerd socket is root only' "$(ls -l /run/containerd/containerd.sock)" '^srw-rw---- 1 root root 0 .* /run/containerd/containerd\.sock$'
expect_equal 'interfaces: the kubelet settings match the page' "$(sudo grep -A4 -E 'anonymous|authorization|readOnlyPort' /var/lib/kubelet/config.yaml)" "$(output_from_page "$page" 'sudo grep -A4')"
columns="$(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTNETWORK:.spec.hostNetwork,HOSTPID:.spec.hostPID)"
printf '%s\n' "$columns"
for pod in "etcd-$cluster" "kube-apiserver-$cluster" "kube-controller-manager-$cluster" "kube-scheduler-$cluster" 'kube-proxy-[a-z0-9]+'; do
  expect_match "interfaces: $pod uses the host network" "$columns" "^kube-system +$pod +true +<none>$"
done
expect_equal 'interfaces: no other pod uses the host network' "$(printf '%s\n' "$columns" | sed 1d | grep -E ' true ' | grep -cvE " (etcd|kube-apiserver|kube-controller-manager|kube-scheduler)-$cluster | kube-proxy-" || true)" 0
expect_equal 'interfaces: two coredns pods without host namespaces' "$(printf '%s\n' "$columns" | grep -cE '^kube-system +coredns-[a-z0-9]+-[a-z0-9]+ +<none> +<none>$')" 2
expect_equal 'interfaces: the starfleet and outpost pods without host namespaces' "$(printf '%s\n' "$columns" | grep -cE '^(starfleet|outpost) +[a-z0-9-]+ +<none> +<none>$')" 4
expect_equal 'interfaces: no pod uses the host PID namespace' "$(printf '%s\n' "$columns" | sed 1d | grep -cv '<none>$' || true)" 0
save_file_from_page "$page" pod-host-reader.yaml
expect_equal 'interfaces: apply creates host-reader' "$(kubectl apply -f pod-host-reader.yaml)" 'pod/host-reader created'
expect_equal 'interfaces: host-reader becomes Ready' "$(kubectl -n starfleet wait --for=condition=Ready pod/host-reader --timeout=120s)" 'pod/host-reader condition met'
expect_equal 'interfaces: the pod reads the node host name' "$(kubectl -n starfleet exec host-reader -- cat /host-etc/hostname)" "$cluster"
expect_equal 'interfaces: delete removes host-reader' "$(kubectl -n starfleet delete pod host-reader)" 'pod "host-reader" deleted from starfleet namespace'
expect_equal 'interfaces: label sets baseline' "$(kubectl label namespace starfleet pod-security.kubernetes.io/enforce=baseline)" 'namespace/starfleet labeled'
expect_equal 'interfaces: the API server rejects the hostPath pod' "$(kubectl apply -f pod-host-reader.yaml 2>&1 || true)" 'Error from server (Forbidden): error when creating "pod-host-reader.yaml": pods "host-reader" is forbidden: violates PodSecurity "baseline:latest": hostPath volumes (volume "host-etc")'
expect_equal 'interfaces: removing the label undoes the experiment' "$(kubectl label namespace starfleet pod-security.kubernetes.io/enforce-)" 'namespace/starfleet unlabeled'

if [[ "$failures" -gt 0 ]]; then
  printf 'FAIL: %s of %s checks failed\n' "$failures" "$checks" >&2
  exit 1
fi
printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
