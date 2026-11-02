# Get Your Machine Ready

Practical work uses isolated Kubernetes clusters on your machine. Install astrona, kubectl, kind, Podman, Python 3, Helm and OpenSSL. kubectl sends requests to the cluster API. kind creates disposable Kubernetes nodes as containers. Podman supplies the container engine. Some exercises use Helm to install a supplied chart, while certificate exercises use OpenSSL.

Confirm that the tools are available and the container engine is running. On systems where Podman uses a virtual machine, that machine must also be running. Leave adequate capacity for multiple node containers and the controllers an exercise installs. High-availability and service-mesh environments use more resources than the ordinary two-node environments.

```sh
astrona --version
kubectl version --client
kind version
podman info
python3 --version
helm version --short
openssl version
```

From the local course checkout, start an ungraded environment through its configuration directory. These authored changes must be available in the checkout you use; the draft content is not a claim of course publication.

```sh
astrona run -c sections/section-010/module-01/playground
```

Select the private kubeconfig before sending cluster requests. A kubeconfig contains the API address and credentials used by kubectl. Check the expected context before any change so a shell that previously selected another cluster cannot redirect your commands.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-033-playground-010-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-033-playground-010-01" || exit 1
kubectl get nodes
```

The playground guide contains its complete practice sequence. Independent graded tasks launch separate environments with separate names and connection commands. Keep the connection for the task you are completing. The final summary removes the module playground; each independent task gives its own removal command.

If startup fails, inspect the actual error. An unavailable engine, a busy published port, insufficient capacity and an addon download failure are different problems. Configuration validation can inspect references before startup, but it cannot prove the runtime or network is available. Record real output when reporting a failure, and identify the environment name. The pinned node image provides a practice baseline rather than a promise of parity with the current examination environment.
