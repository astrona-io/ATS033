#!/usr/bin/env bash
# Smoke test of the start state that docs/overview.md describes.
# scripts/ci/test-playground.sh runs this file inside the playground VM as
# the student user. It exits non-zero when one fact is not as the page says.
set -euo pipefail
cluster="astro-ats-033-playground-010-02"
if [[ "$(kubectl config current-context)" != "kubernetes-admin@$cluster" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi

# The cluster is ready and the workloads of the pages run.
kubectl -n starfleet rollout status deployment/probe --timeout=60s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=60s
kubectl get --raw=/readyz >/dev/null

fail() {
  printf 'smoke: %s\n' "$1" >&2
  exit 1
}

kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=60s
probe_reply=$(kubectl -n starfleet exec shuttle -- wget -qO- -T 5 http://probe)
[[ "$probe_reply" == version=v1* ]] || fail "the probe Service answered: $probe_reply"

# The effective sshd settings allow root and password logins, and no
# AllowUsers list limits the accounts.
effective_settings=$(sudo sshd -T)
grep -qx 'permitrootlogin yes' <<<"$effective_settings" || fail 'sshd -T does not show permitrootlogin yes'
grep -qx 'passwordauthentication yes' <<<"$effective_settings" || fail 'sshd -T does not show passwordauthentication yes'
grep -qx 'pubkeyauthentication yes' <<<"$effective_settings" || fail 'sshd -T does not show pubkeyauthentication yes'
if grep -q '^allowusers ' <<<"$effective_settings"; then fail 'sshd -T already shows an allowusers line'; fi
sudo grep -qx 'PasswordAuthentication yes' /etc/ssh/sshd_config.d/50-cloud-init.conf ||
  fail '50-cloud-init.conf does not set PasswordAuthentication yes'

# The unused account still has a login shell, a password and an SSH key.
[[ "$(getent passwd olduser | cut -d: -f7)" == /bin/bash ]] || fail 'olduser does not have the shell /bin/bash'
[[ "$(sudo passwd -S olduser | cut -d' ' -f2)" == P ]] || fail 'olduser does not have a usable password'
sudo test -s /home/olduser/.ssh/authorized_keys || fail 'olduser has no authorized_keys file'
getent passwd opsadmin >/dev/null || fail 'the account opsadmin does not exist'

for service in kubelet.service containerd.service ssh.service; do
  [[ "$(systemctl is-active "$service")" == active ]] || fail "$service is not active"
done
printf 'smoke: start state of %s matches docs/overview.md\n' "$cluster"
