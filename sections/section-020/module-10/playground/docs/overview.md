---
exam_objectives:
- Using least-privilege identity and access management
---
# Guided Practice: Grant One Host Identity Scoped Read Access

This playground is a virtual machine (VM) that runs a one-node Kubernetes cluster built with kubeadm, so the VM is the node. The task is to give the account `training-reader` read access to one report file, without making the file public and without giving the account root. Open a shell on the VM and confirm the cluster:

<!-- astrona:playground:renew -->

```sh
astrona ssh astro-ats-033-playground-020-01
kubectl config current-context
kubectl get nodes
```

```text
kubernetes-admin@astro-ats-033-playground-020-01
NAME                              STATUS   ROLES           AGE   VERSION
astro-ats-033-playground-020-01   Ready    control-plane   58s   v1.35.10
```

You are logged in as `student`. This user may run any command as `root` through `sudo`, and its kubeconfig file (the file that tells `kubectl` which cluster to use and which credentials to send) gives administrator access to the cluster. The changes stay inside this VM.

## Inspect the start state

The setup created the account, the group `training-readers` and two files in `/var/lib/training-identity`. Look at the account and at the owner, group and mode of each file:

```sh
id training-reader
sudo ls -l /var/lib/training-identity
```

```text
uid=1003(training-reader) gid=1004(training-reader) groups=1004(training-reader)
total 8
-rw------- 1 root root             26 Nov 18 09:02 private-report
-rw-r----- 1 root training-readers 18 Nov 18 09:02 public-report
```

`public-report` gives read access to the group `training-readers` (mode `-rw-r-----`). `private-report` gives access to `root` only. The account is not in the group yet, so the kernel applies the "other" bits, which are empty. Test it as the account with `runuser`, which starts a process as another user:

```sh
sudo runuser -u training-reader -- cat /var/lib/training-identity/public-report
```

```text
cat: /var/lib/training-identity/public-report: Permission denied
```

## Grant the access and test it

Add the account to the group. `--append` keeps the groups the account already has; without it, `usermod --groups` replaces the whole list. Then test both files as the account:

```sh
sudo usermod --append --groups training-readers training-reader
sudo runuser -u training-reader -- cat /var/lib/training-identity/public-report
sudo runuser -u training-reader -- cat /var/lib/training-identity/private-report
id training-reader
```

```text
disposable-report
cat: /var/lib/training-identity/private-report: Permission denied
uid=1003(training-reader) gid=1004(training-reader) groups=1004(training-reader),1003(training-readers)
```

The account reads `public-report` and is still denied `private-report`. Its UID (user ID) is not 0, and its groups do not include `root`. The file owners and modes did not change.

## Record the review in the cluster

Record the result as a ConfigMap, a Kubernetes object that stores key-value data. Save this as `configmap-identity-review.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: identity-review
  namespace: starfleet
data:
  identity: training-reader
  result: scoped-read
```

Apply it:

```sh
kubectl apply -f configmap-identity-review.yaml
```

```text
configmap/identity-review created
```

Then check the result:

```sh
kubectl -n starfleet get configmap identity-review -o jsonpath='{.data}'
```

```text
{"identity":"training-reader","result":"scoped-read"}
```

The account now has exactly one extra permission, and the cluster holds a record of the review. When you are done, leave the VM with `exit` and remove the playground with `astrona destroy ats-033-playground-020-01`.

## Common pitfalls

> [!WARNING]
> - **Testing as `root` or `student`.** `root` reads every file, so a test with `sudo cat` proves nothing. Test with `sudo runuser -u training-reader --`.
> - **Forgetting `--append`.** `usermod --groups` without it removes every other supplementary group.
> - **Opening the file to everyone.** `chmod o+r` lets every account read the report. Use the group.
