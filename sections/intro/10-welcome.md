# Welcome To The Course

Welcome, and thank you for joining. This course is about one question: how do you harden the nodes of a Kubernetes cluster, so that an attacker who breaks into one container cannot take over the host? You will inspect, lock down, break and fix real nodes and clusters on your own machine. At the end, you will know what each security setting does and why it matters.

This page tells you who the course is for, what you will be able to do, and how the course works. Read it once before you start. It takes about five minutes.

## Who this course is for

This course is for people who already use Kubernetes and now want to secure it. You should be able to create a pod, a Deployment and a Service with `kubectl`, and read a YAML file without help. You should also be able to work in a Linux shell: move between folders, read a file and run a command with `sudo`. You do not need any security background. The course explains every security term the first time it appears.

Many readers prepare for the Certified Kubernetes Security Specialist (CKS) exam. The CKS is a hands-on exam from the Cloud Native Computing Foundation (CNCF) and the Linux Foundation. You solve tasks on live clusters from a terminal, with a time limit. This course covers the System Hardening domain of that exam, which is worth 10% of the score. If you do not plan to take the exam, the course still teaches skills you can use at work every day.

This course is independent practice material. It follows the official objectives, but it does not claim to copy the exam environment.

## What you will be able to do

The course follows the official System Hardening objectives. When you finish, you will be able to:

- Find the services, packages and listeners a node does not need and remove them, lock down SSH logins, and keep pods away from the host.
- Give Linux users, Kubernetes identities and ServiceAccounts only the access their job needs, and take that access away again.
- Close the network ports nobody needs, limit how Services are exposed outside the cluster, and protect the API server, the kubelet and etcd.
- Filter system calls with seccomp, confine files and capabilities with AppArmor, and fix the profiles that break a pod.

Each of these is a section of the course, and the sections come in this order.

## Words you will see

A few words come back on almost every page. The course uses the real Kubernetes terms, because these are the words you meet in the documentation, in the logs and in the exam.

- **Cluster:** a group of machines that run Kubernetes together.
- **Node:** one machine in the cluster. The control plane node runs the cluster's management parts; a worker node runs your pods.
- **Host:** the operating system of a node. Every container on a node shares the kernel of its host.
- **API server (kube-apiserver):** the control plane component that receives every request to the cluster, checks it and stores the result.
- **etcd:** the database where the API server stores the state of the cluster.
- **kubelet:** the agent on each node that starts and stops the containers of a pod.
- **Namespace:** a named group of objects inside a cluster. Many security rules apply to one namespace at a time.
- **ServiceAccount:** the identity that a pod uses when it sends requests to the API server.
- **Manifest:** a YAML file that describes a Kubernetes object you want to create.
- **systemd:** the program that starts and stops the services of a Linux host, such as the SSH daemon or the kubelet.

Each module defines the other terms it needs, such as seccomp profile, AppArmor profile or NodePort, when they first appear.

## The example application

Every example and lab uses the same small application, so you can focus on the security setting and not on a new app each time. The workloads have short names, such as `probe`, `shuttle`, `drifter` and `ledger`. Most of them run in a namespace called `starfleet`, and a second namespace called `outpost` plays the role of another team or an untrusted client.

The names have no technical meaning. They are just easy to tell apart in a command or a log line. In a lab, the namespace names get a number at the end, for example `starfleet-033-020-03-01`, so that each lab has its own namespaces and labs never get in each other's way.

## How the course is laid out

The course has one section for each objective. Each section starts with a short introduction and a list of what you will learn in it. A section then has several modules, and each module covers one topic.

A module has four kinds of pages. The landing page lists the goals, what you should know first and the order of the parts. The parts do the real teaching, one idea per part. A graded lab comes right after the part it practises. The summary page closes the module and repeats the key ideas, and a short knowledge check follows it.

Every module also comes with a playground. A playground is a private, ungraded practice environment that runs on your machine. You use it to follow the hands-on steps in the parts. Labs run in their own separate environment, so you can try things in the playground without any risk to your lab score.

The type of playground depends on what the module teaches. Some modules use kind (Kubernetes in Docker), a tool that runs each Kubernetes node as a container. A kind playground in this course has one control plane node and one worker node with Kubernetes v1.35, and it is enough for work with objects such as Roles, ServiceAccounts, Services or seccomp profiles. When a module needs a full machine, for example to stop services, remove packages, change the SSH settings, the firewall, the kubelet, etcd or the AppArmor profiles of a node, the playground runs as a QEMU virtual machine instead. QEMU is an emulator that runs a complete operating system on your computer. The virtual machine runs Ubuntu 24.04 and holds a one-node cluster built with kubeadm, the standard tool that installs and upgrades a cluster on a Linux machine. It takes longer to start and uses more memory, but it behaves like a real server.

## How to read a page

Each part reads like a short chapter of a book. It opens with the problem it solves, explains how the system works, and then shows it on the playground. You run each command yourself and compare your output with the output on the page. The output on the pages comes from real runs, so names, addresses and ages in your output can differ. Allow about 15 minutes per part, including the hands-on steps.

Each part ends with a "Common pitfalls" box. It lists the mistakes people make most often with that topic. Read it carefully, because many exam tasks test exactly these details.

When you reach a lab, try to solve the task on your own first. The task tells you what the result must look like, and the platform checks your cluster when you submit. Open the solution only when you are done or truly stuck. You learn the most when you find the answer yourself. Some labs change a node, and those commands only touch the private node containers or the private virtual machine of that lab.

Ready? The next page shows you how to set up your machine for the course.
