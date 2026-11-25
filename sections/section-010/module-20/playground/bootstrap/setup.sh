#!/usr/bin/env bash
# Runs inside the playground VM as the astrona user. astrona copies only this
# file into the VM, so the start objects are inlined below.
set -euo pipefail
cluster="astro-ats-033-playground-010-02"
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
# SSH settings that an old image build left behind. The drop-in directory is
# included near the top of the main file, so sshd reads 50-cloud-init.conf
# before the lines appended to the main file, and its value wins.
sudo tee /etc/ssh/sshd_config.d/50-cloud-init.conf >/dev/null <<'CLOUD'
PasswordAuthentication yes
CLOUD
sudo tee -a /etc/ssh/sshd_config >/dev/null <<'MAIN'

# Settings added by the image build.
PermitRootLogin yes
PasswordAuthentication no

Match User backup
    # The backup account may only copy files.
    ForceCommand internal-sftp
    AllowTcpForwarding no
MAIN
sudo sshd -t
sudo systemctl reload ssh
# A current administrator and an account that nobody uses any more. Both
# have a password and a login shell; olduser also has an SSH public key.
for account in opsadmin olduser; do
  getent passwd "$account" >/dev/null || sudo useradd --create-home --shell /bin/bash "$account"
done
printf 'opsadmin:Ops-Admin-2026\nolduser:Old-User-2019\n' | sudo chpasswd
key_directory=$(mktemp -d)
ssh-keygen -q -t ed25519 -N '' -C olduser@old-laptop -f "$key_directory/olduser"
sudo install -d -o olduser -g olduser -m 0700 /home/olduser/.ssh
sudo install -o olduser -g olduser -m 0600 "$key_directory/olduser.pub" /home/olduser/.ssh/authorized_keys
rm -rf "$key_directory"
