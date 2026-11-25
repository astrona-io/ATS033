#!/usr/bin/env bash
# Runs inside the playground VM as the astrona user. astrona copies only this
# file into the VM, so the start objects are inlined below.
set -euo pipefail
cluster="astro-ats-033-playground-030-03"
# The learner logs in as student, so student gets the admin kubeconfig too.
kube_users=(--user "$(id -un)")
getent passwd student >/dev/null && kube_users+=(--user student)
sudo /usr/local/sbin/astrona-kubeadm-init --cluster-name "$cluster" "${kube_users[@]}"
if [[ "$(kubectl config current-context)" != "kubernetes-admin@$cluster" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
kubectl apply -f - <<'MANIFEST'
apiVersion: v1
kind: Namespace
metadata:
  name: starfleet
  labels:
    project: cks
---
apiVersion: v1
kind: Namespace
metadata:
  name: outpost
  labels:
    project: outpost
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: probe-code
  namespace: starfleet
data:
  server.py: "from http.server import BaseHTTPRequestHandler, HTTPServer\nfrom pathlib\
    \ import Path\nimport os\nimport socket\n\nclass Handler(BaseHTTPRequestHandler):\n\
    \    def do_GET(self):\n        marker = {\"/ready\": \"/tmp/not-ready\", \"/health\"\
    : \"/tmp/unhealthy\"}.get(self.path)\n        status = 503 if marker and Path(marker).exists()\
    \ else 200\n        settings = Path(\"/settings/greeting\")\n        greeting\
    \ = settings.read_text().strip() if settings.exists() else os.getenv(\"GREETING\"\
    , \"hello\")\n        body = f\"version={os.getenv('VERSION', 'v1')} host={socket.gethostname()}\
    \ greeting={greeting}\\n\"\n        self.send_response(status)\n        self.send_header(\"\
    Content-Type\", \"text/plain\")\n        self.end_headers()\n        self.wfile.write(body.encode())\n\
    \nHTTPServer((\"0.0.0.0\", 8080), Handler).serve_forever()\n"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe
  namespace: starfleet
spec:
  replicas: 2
  selector:
    matchLabels:
      app: probe
      release: probe
  template:
    metadata:
      labels:
        app: probe
        release: probe
    spec:
      containers:
      - name: probe
        image: docker.io/library/python:3.13-alpine
        command:
        - python
        - /app/server.py
        env:
        - name: VERSION
          value: v1
        ports:
        - name: http
          containerPort: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          periodSeconds: 2
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            memory: 128Mi
        volumeMounts:
        - name: app
          mountPath: /app
          readOnly: true
      volumes:
      - name: app
        configMap:
          name: probe-code
---
apiVersion: v1
kind: Service
metadata:
  name: probe
  namespace: starfleet
spec:
  selector:
    app: probe
    release: probe
  ports:
  - name: http
    port: 80
    targetPort: http
---
apiVersion: v1
kind: Pod
metadata:
  name: shuttle
  namespace: starfleet
  labels:
    app: shuttle
spec:
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
  restartPolicy: Never
---
apiVersion: v1
kind: Pod
metadata:
  name: drifter
  namespace: outpost
  labels:
    app: drifter
spec:
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
  restartPolicy: Never
MANIFEST
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=120s

# Weaken the kubelet for the guided practice: it accepts anonymous requests
# and allows every request.
sudo sed -i '/^authentication:/,/^  webhook:/ s/enabled: false/enabled: true/' /var/lib/kubelet/config.yaml
sudo sed -i 's/^  mode: Webhook$/  mode: AlwaysAllow/' /var/lib/kubelet/config.yaml
sudo systemctl restart kubelet
for attempt in $(seq 1 60); do
  if sudo curl -sk --max-time 3 https://127.0.0.1:10250/healthz >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
kubectl wait --for=condition=Ready "node/$(hostname)" --timeout=180s
