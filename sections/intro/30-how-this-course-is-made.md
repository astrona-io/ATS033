# How This Course Is Made

You will trust a course more when you know how it is made. This page explains how the authors write the content, how they check it, who the authors are, and what to do when you find a mistake.

## How the content is written

The course starts from the official System Hardening objectives of the Certified Kubernetes Security Specialist (CKS) exam. Each objective becomes a section, and each section is split into modules small enough to learn in one sitting. The authors check every technical claim against the official Kubernetes documentation and the documentation of the other tools the course uses.

The course uses the real technical terms, the same words you see in the product, the logs and the exam. When a new term comes up for the first time, the page explains what it means in simple words. Each page also makes clear which part of the system does the work, for example whether the Linux kernel, the kubelet or the container runtime enforces a rule. You always see a real example first, and the general rule comes after it.

## How the content is checked

Every command and every configuration file on the pages is written for the same playground you run. The authors never invent command output. When a page shortens a long output, it says so.

Each graded lab has a script that checks your cluster when you submit. The script runs one check for each part of the task. The authors test each lab in two ways. First, the checks must all fail on a fresh lab that nobody has touched. Then, the checks must all pass after the reference solution runs. This makes sure the lab grades the task and not something else.

The authors are still running every lab and playground from start to finish on a live machine. If something does not work the way a page says, it is most likely a mistake on our side, and we want to hear about it.

## About the authors

Every course has people behind it. Authors write the pages, the labs and the questions. Maintainers review every change, answer your reports, and keep the labs working as Kubernetes and its tools move on. Many more people help by reporting mistakes and sending fixes, and you can see all of them on the [contributors](https://github.com/astrona-io/ATS033/graphs/contributors) page.

<table>
  <tr>
    <td align="center" valign="top" width="120"><img src="images/author/parisnakitakejser.png" alt="Paris Nakita Kejser" width="120"></td>
    <td><strong>Paris Nakita Kejser</strong><br>Paris is the founder of Astrona.io and a Golden Kubestronaut, one of a small group of engineers who hold every Cloud Native Computing Foundation (CNCF) certification. As a public speaker and an active voice in local CNCF meetup groups, Paris shares practical cloud native knowledge with the community. Astrona.io brings that same hands-on approach to every learner.<br><a href="https://github.com/parisnakitakejser">GitHub</a> · <a href="https://www.linkedin.com/in/parisnakitakejser/">LinkedIn</a></td>
  </tr>
</table>

## Report a mistake

If you find an error, a step that does not work or a sentence that is hard to understand, please [report a mistake](https://github.com/astrona-io/ATS033/issues). Say which page it is on, quote the sentence or command, and describe what you expected to happen. If a playground or lab failed, add its name and the exact error message. Every report helps the next reader.

## License and ownership

This course is created by Astrona.io. You may use, change and share it for free, as long as you do not earn money with it and you keep the names of its authors and maintainers. The text, images and questions use the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 license, and the scripts and lab files use the GNU Affero General Public License v3. The [license](https://github.com/astrona-io/ATS033/blob/main/NOTICE) notice explains which part uses which license. For commercial use, contact Astrona.io. The CKS exam and its objectives belong to the Cloud Native Computing Foundation (CNCF) and the Linux Foundation. This course is independent practice material: the text, the labs and the practice questions are original, and none of them are real exam questions.

The names of the example workloads, such as `starfleet` and `probe`, are only labels. They have no special technical meaning.

With that, the introduction is complete. The course now starts with reducing the attack surface of the host operating system.
