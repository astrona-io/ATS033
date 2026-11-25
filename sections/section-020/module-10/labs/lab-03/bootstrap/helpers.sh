# Helper functions for the setup and solution scripts of a qemu lab.
# The scripts run inside the lab VM, which is the only node of the cluster:
# node_name and worker_name both name it, and node commands run with sudo.
# The calling script sets node_name, worker_name and namespace after its
# context guard.

run_on_node() {
  sudo "$@"
}

run_on_worker() {
  sudo "$@"
}

# Print the command line of the newest process with this program name,
# one argument on each line. Prints nothing when the process is not running.
process_arguments() {
  local program="$2" pid
  pid="$(sudo pgrep -n -f "^(/[^ ]*/)?$program( |\$)" || true)"
  if [[ -n "$pid" ]]; then
    sudo cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' '\n' || true
  fi
}

# Wait until the running process has (present) or no longer has (absent)
# one exact argument, for example --profiling=false.
wait_for_argument() {
  local container="$1" program="$2" argument="$3" state="$4" arguments attempt
  for attempt in $(seq 1 80); do
    arguments="$(process_arguments "$container" "$program")"
    if [[ -n "$arguments" ]]; then
      if [[ "$state" == present ]] && grep -qxF -- "$argument" <<<"$arguments"; then
        return 0
      fi
      if [[ "$state" == absent ]] && ! grep -qxF -- "$argument" <<<"$arguments"; then
        return 0
      fi
    fi
    sleep 3
  done
  printf 'Timed out: %s argument %s is not %s\n' "$program" "$argument" "$state" >&2
  return 1
}

# Wait until the API server answers /readyz with ok.
wait_for_api() {
  local attempt
  for attempt in $(seq 1 100); do
    if [[ "$(kubectl --request-timeout=3s get --raw=/readyz 2>/dev/null)" == ok ]]; then
      return 0
    fi
    sleep 3
  done
  printf 'Timed out waiting for the API server\n' >&2
  return 1
}

# Wait until the Ready condition of a kube-system pod has one value (True or
# False). The mirror pod of a static pod can be replaced while the kubelet
# restarts it, so a missing pod counts as "not yet".
wait_for_pod_ready() {
  local pod="$1" expected="$2" attempt
  for attempt in $(seq 1 60); do
    if [[ "$(kubectl -n kube-system get pod "$pod" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" == "$expected" ]]; then
      return 0
    fi
    sleep 3
  done
  printf 'Timed out waiting for pod %s Ready=%s\n' "$pod" "$expected" >&2
  return 1
}

# Edit a static pod manifest the safe way: copy it to a work directory
# outside /etc/kubernetes/manifests, run sed on the copy, move it back.
edit_manifest() {
  local component="$1" expression="$2"
  local manifest="/etc/kubernetes/manifests/$component.yaml" copy="/etc/kubernetes/edit/$component.yaml"
  run_on_node mkdir -p /etc/kubernetes/edit
  run_on_node cp -p "$manifest" "$copy"
  run_on_node sed -i "$expression" "$copy"
  run_on_node mv "$copy" "$manifest"
}

# Replace or add one top-level field in the kubelet configuration file.
set_kubelet_field() {
  run_on_worker sed -i "/^$1:/d" /var/lib/kubelet/config.yaml
  run_on_worker sh -c "printf '\n%s: %s\n' '$1' '$2' >> /var/lib/kubelet/config.yaml"
}

# Wait until the effective kubelet configuration (configz) holds a text
# (present, the default) or no longer holds it (absent).
wait_for_configz() {
  local expected="$1" state="${2:-present}" attempt current
  for attempt in $(seq 1 60); do
    if current="$(kubectl --request-timeout=3s get --raw "/api/v1/nodes/$worker_name/proxy/configz" 2>/dev/null)"; then
      if [[ "$state" == present ]] && grep -qF -- "$expected" <<<"$current"; then
        return 0
      fi
      if [[ "$state" == absent ]] && ! grep -qF -- "$expected" <<<"$current"; then
        return 0
      fi
    fi
    sleep 3
  done
  printf 'Timed out waiting for kubelet configuration %s %s\n' "$expected" "$state" >&2
  return 1
}

# Wait until the worker node reports Ready.
wait_for_worker() {
  kubectl wait --for=condition=Ready "node/$worker_name" --timeout=180s
}

# Run a short pod with the kube-bench image in the lab namespace, wait until
# it has finished and print its log. The pod reads only its own image.
kube_bench_image_output() {
  local name="$1" script="$2"
  kubectl -n "$namespace" delete pod "$name" --ignore-not-found --wait=true >/dev/null
  kubectl -n "$namespace" run "$name" --restart=Never --image-pull-policy=IfNotPresent \
    --image=docker.io/aquasec/kube-bench:v0.10.6 --command -- sh -c "$script" >/dev/null
  kubectl -n "$namespace" wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$name" --timeout=120s >/dev/null
  kubectl -n "$namespace" logs "pod/$name"
  kubectl -n "$namespace" delete pod "$name" --wait=false >/dev/null
}
