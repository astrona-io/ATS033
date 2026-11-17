---
exam_objectives:
- Appropriately use kernel hardening tools such as AppArmor, seccomp
---
# Drop All Capabilities Except NET_BIND_SERVICE Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-lab-040-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-lab-040-03-03" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Read The Starting State

A Linux capability is one unit of root power, such as `CHOWN` (change the owner of a file) or `NET_BIND_SERVICE` (listen on a port below 1024). The kernel shows the capability sets of a process in `/proc/<pid>/status` as hexadecimal masks. `CapBnd` is the bounding set, the upper limit for the process and its children. `CapEff` is the set the process uses right now. `NoNewPrivs` shows whether the process may gain more rights later. Read them for the main process of the running pod:

```sh
kubectl -n starfleet-033-040-03-03 exec deploy/relay -- grep -E 'CapBnd|CapEff|NoNewPrivs' /proc/1/status
kubectl -n starfleet-033-040-03-03 exec deploy/relay -- id
```

```text
CapEff:	000001ffffffffff
CapBnd:	000001ffffffffff
NoNewPrivs:	0
uid=0(root) gid=0(root) groups=0(root),10(wheel)
```

Every bit is set, because a privileged container gets every capability the kernel knows. `NoNewPrivs: 0` means escalation is allowed. The process is root, so it can change file owners right now. This command works and prints nothing:

```sh
kubectl -n starfleet-033-040-03-03 exec deploy/relay -- chown 1000 /www/index.html
```

## Change The Security Context

Three fields in the container `securityContext` do the work. `privileged: false` removes the full set. `allowPrivilegeEscalation: false` makes the container runtime set the kernel flag `no_new_privs` on the process. `capabilities.drop: [ALL]` removes the default capabilities, and `capabilities.add: [NET_BIND_SERVICE]` adds back the one the web server needs. The rest of the Deployment stays as it was.

Save this as `deployment-relay.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: relay
  namespace: starfleet-033-040-03-03
spec:
  replicas: 1
  selector:
    matchLabels:
      app: relay
  template:
    metadata:
      labels:
        app: relay
    spec:
      containers:
      - name: relay
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - mkdir -p /www && echo relay-ok > /www/index.html && httpd -f -p 80 -h /www
        ports:
        - name: http
          containerPort: 80
        readinessProbe:
          tcpSocket:
            port: http
          periodSeconds: 5
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
```

Apply it:

```sh
kubectl apply -f deployment-relay.yaml
```

```text
deployment.apps/relay configured
```

The pod template changed, so the Deployment controller creates a new pod and removes the old one. Wait for the rollout:

```sh
kubectl -n starfleet-033-040-03-03 rollout status deployment/relay --timeout=180s
```

```text
Waiting for deployment "relay" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "relay" rollout to finish: 1 old replicas are pending termination...
deployment "relay" successfully rolled out
```

The old pod can stay in `Terminating` for about 30 seconds. Process 1 in the container does not install a handler for the `SIGTERM` signal, and the kernel ignores such a signal for process 1 of a PID namespace. The kubelet therefore waits for the grace period of 30 seconds before it kills the process. This output was taken 30 seconds after the rollout:

```sh
kubectl -n starfleet-033-040-03-03 get pods
```

```text
NAME                    READY   STATUS        RESTARTS   AGE
relay-8cd7546bd-hw6kw   1/1     Terminating   0          50s
relay-9c86c485-nxrkg    1/1     Running       0          31s
```

## Verify The Result

`kubectl exec deploy/relay` picks a pod that is not being deleted, so it reads the new pod:

```sh
kubectl -n starfleet-033-040-03-03 exec deploy/relay -- grep -E 'CapBnd|CapEff|NoNewPrivs' /proc/1/status
```

```text
CapEff:	0000000000000400
CapBnd:	0000000000000400
NoNewPrivs:	1
```

Bit number 10 is `NET_BIND_SERVICE`, and `0x400` is exactly that bit. The process is still root, so its effective set holds the added capability. For a non-root process, `CapEff` would be empty, and `CapBnd` would be the field to read. `NoNewPrivs: 1` shows that escalation is blocked.

The web server still listens on port 80, because it holds `NET_BIND_SERVICE`:

```sh
kubectl -n starfleet-033-040-03-03 exec deploy/relay -- wget -qO- http://127.0.0.1:80/
```

```text
relay-ok
```

The last check must fail. The user is still root, but root without `CHOWN` cannot change the owner of a file:

```sh
kubectl -n starfleet-033-040-03-03 exec deploy/relay -- chown 1000 /www/index.html
```

```text
chown: /www/index.html: Operation not permitted
command terminated with exit code 1
```

The same command worked before the change. The user ID did not change; only the capability set did.

After recording the result, remove this independent lab with `astrona destroy ats-033-lab-040-03-03`.

## Common pitfalls

> [!WARNING]
> - Keeping `privileged: true` next to the `capabilities` field. A privileged container gets every capability, and the `drop` list has no effect.
> - Writing `CAP_NET_BIND_SERVICE` in the manifest. Kubernetes expects the name without the `CAP_` prefix.
> - Reading the old pod right after the rollout. It still shows the full mask until it is gone. Use `deploy/relay`, which picks the new pod.
