---
exam_objectives:
- Minimize external access to the network
---
# Remove Anonymous Access From RBAC Bindings Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-033-lab-030-03-02
kubectl config current-context
```

```text
kubernetes-admin@astro-ats-033-lab-030-03-02
```

You are logged in as the `student` user, which has a kubeconfig file for the cluster.

## Step 1: Find the bindings that name anonymous callers

RBAC (role-based access control) gives permissions through bindings. A RoleBinding or ClusterRoleBinding links a role to subjects: users, groups or ServiceAccounts. The API server gives a request without credentials the user name `system:anonymous` and the group `system:unauthenticated`. So look for bindings that list one of these two names:

```sh
kubectl get clusterrolebindings -o wide
kubectl get rolebindings -A -o wide
```

The output below is shortened to the header lines and the lines that name `system:anonymous` or `system:unauthenticated`:

```text
NAME                                                            ROLE                                                                               AGE   USERS                            GROUPS                                            SERVICEACCOUNTS
namespace-reader                                                ClusterRole/namespace-reader                                                       20s   system:anonymous                 ops-team
system:public-info-viewer                                       ClusterRole/system:public-info-viewer                                              37s                                    system:authenticated, system:unauthenticated
NAMESPACE                 NAME                                                ROLE                                                  AGE   USERS                                                   GROUPS                                                          SERVICEACCOUNTS
kube-public               kubeadm:bootstrap-signer-clusterinfo                Role/kubeadm:bootstrap-signer-clusterinfo             36s   system:anonymous
starfleet-033-030-03-02   pod-reader                                          Role/pod-reader                                       20s                                                           system:unauthenticated                                          starfleet-033-030-03-02/shuttle
```

Two of these bindings are built in. `system:public-info-viewer` lets anyone read `/healthz` and `/version`, which is what keeps health checks working. `kubeadm:bootstrap-signer-clusterinfo` lets new nodes read the public `cluster-info` ConfigMap in `kube-public` when they join. The other two are the problem: `namespace-reader` gives `system:anonymous` the ClusterRole `namespace-reader`, and `pod-reader` gives the group `system:unauthenticated` the Role `pod-reader`.

## Step 2: Prove the access without credentials

`curl` without a client certificate or token sends an anonymous request. Run it on the node against the API server. `-o /dev/null -w '%{http_code}\n'` prints only the HTTP status code:

```sh
curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:6443/api/v1/namespaces
curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:6443/api/v1/namespaces/starfleet-033-030-03-02/pods
curl -sk https://127.0.0.1:6443/healthz
```

```text
200
200
ok
```

Both lists answer with `200`, so any caller who reaches port 6443 can read them. `/healthz` answers `ok`, and that must stay.

It is tempting to ask the authorizer with `kubectl auth can-i list namespaces --as=system:anonymous`. In this cluster that does not work:

```text
Error from server (Forbidden): selfsubjectaccessreviews.authorization.k8s.io is forbidden: User "system:anonymous" cannot create resource "selfsubjectaccessreviews" in API group "authorization.k8s.io" at the cluster scope
```

The output above is cut at the end of the line. `kubectl auth can-i` sends a SelfSubjectAccessReview as the impersonated user, and `system:anonymous` may not create one. So test anonymous access with a real request, as above, and read the bindings.

## Step 3: Remove the anonymous subjects

Keep the bindings and their other subjects. Only the anonymous subject goes. Save this as `clusterrolebinding-namespace-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: namespace-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: namespace-reader
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: ops-team
```

Save this as `rolebinding-pod-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader
  namespace: starfleet-033-030-03-02
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
subjects:
- kind: ServiceAccount
  name: shuttle
  namespace: starfleet-033-030-03-02
```

Apply it:

```sh
kubectl apply -f clusterrolebinding-namespace-reader.yaml
kubectl apply -f rolebinding-pod-reader.yaml
```

```text
clusterrolebinding.rbac.authorization.k8s.io/namespace-reader configured
rolebinding.rbac.authorization.k8s.io/pod-reader configured
```

`kubectl apply` replaces the whole `subjects` list with the list in the file. The `roleRef` of a binding cannot change, and these files keep it the same.

## Step 4: Check the result

Then check the result. Read both bindings, repeat the anonymous requests, and check that the named subjects keep their access:

```sh
kubectl get clusterrolebinding namespace-reader -o wide
kubectl -n starfleet-033-030-03-02 get rolebinding pod-reader -o wide
curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:6443/api/v1/namespaces
curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1:6443/api/v1/namespaces/starfleet-033-030-03-02/pods
curl -sk https://127.0.0.1:6443/healthz
kubectl auth can-i list namespaces --as=ops-user --as-group=ops-team
kubectl auth can-i list pods -n starfleet-033-030-03-02 --as=system:serviceaccount:starfleet-033-030-03-02:shuttle
```

```text
NAME               ROLE                           AGE   USERS   GROUPS     SERVICEACCOUNTS
namespace-reader   ClusterRole/namespace-reader   20s           ops-team
NAME         ROLE              AGE   USERS   GROUPS   SERVICEACCOUNTS
pod-reader   Role/pod-reader   20s                    starfleet-033-030-03-02/shuttle
403
403
ok
Warning: resource 'namespaces' is not namespace scoped

yes
yes
```

The anonymous requests now get `403 Forbidden`: the API server still accepts them as `system:anonymous`, but RBAC no longer allows the list. `/healthz` still answers `ok` through `system:public-info-viewer`. The group `ops-team` and the ServiceAccount `shuttle` keep their access. The body of a refused request names the user and the missing permission:

```sh
curl -sk https://127.0.0.1:6443/api/v1/namespaces
```

```text
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "namespaces is forbidden: User \"system:anonymous\" cannot list resource \"namespaces\" in API group \"\" at the cluster scope",
  "reason": "Forbidden",
  "details": {
    "kind": "namespaces"
  },
  "code": 403
}
```

After recording your result, remove the independent lab with `astrona destroy ats-033-lab-030-03-02`.

## Common pitfalls

> [!WARNING]
> - **Deleting the whole binding.** `ops-team` and `shuttle` then lose their access too. Remove only the anonymous subject.
> - **Removing only one of the two names.** A binding to the group `system:unauthenticated` opens the same door as a binding to the user `system:anonymous`. Check for both names.
> - **Touching the built-in bindings.** `system:public-info-viewer` keeps `/healthz` open for health checks, and `kubeadm:bootstrap-signer-clusterinfo` lets nodes join. Leave them as they are.
> - **Trusting `kubectl auth can-i --as=system:anonymous`.** It fails with `Forbidden` on the SelfSubjectAccessReview. Send a real request without credentials instead.
