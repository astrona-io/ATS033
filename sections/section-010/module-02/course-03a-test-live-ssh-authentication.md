---
draft: true
---
# Verify SSH Authentication After A Reload

A correct-looking SSH configuration does not prove that the running server loaded it. Open a fresh connection after a reload and test both access that should work and access that should fail. An existing session may remain open even after new logins are forbidden.

The independent lab uses an Ubuntu QEMU VM. Connect with `astrona ssh ats-033-lab-010-02-01`. A separate service, `training-sshd`, listens on port 2222 and reads `/etc/ssh/sshd_config.training`. This lets you change authentication without removing the VM's management access on port 22. Run the following commands inside that VM.

<!-- astrona:playground:renew -->

Inspect the effective settings for an incoming connection:

```sh
sudo /usr/sbin/sshd -T -f /etc/ssh/sshd_config.training \
  -C user=opsadmin,host=localhost,addr=127.0.0.1
```

`-T` parses the server configuration, including applicable Match blocks; `-C` supplies the connection being evaluated. Reading the first matching line with grep cannot reproduce all of that behavior. Set `PermitRootLogin no`, `PasswordAuthentication no`, `PubkeyAuthentication yes` and `AllowUsers opsadmin` in the training configuration. Keep `KbdInteractiveAuthentication no` so another interactive authentication method does not defeat the intended restriction.

Check the syntax before reloading the service:

```sh
sudo /usr/sbin/sshd -t -f /etc/ssh/sshd_config.training
sudo systemctl reload training-sshd
sudo systemctl is-active training-sshd
```

Use the supplied key for a new administrator connection:

```sh
sudo ssh -p 2222 -i /opt/training-ssh/client -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=accept-new opsadmin@127.0.0.1 'id -un'
```

The command must return `opsadmin`. Repeat it with `root@127.0.0.1` and `olduser@127.0.0.1`; the server must refuse authentication. To test password access specifically, disable the client's public-key method and request password authentication. The fixture's disposable account password is `training-password`.

```sh
ssh -p 2222 -o PubkeyAuthentication=no -o PreferredAuthentications=password \
  opsadmin@127.0.0.1
```

Locking a password does not necessarily disable other authentication methods. For the unused account, also restrict server access and change its login shell:

```sh
sudo usermod -L -s /usr/sbin/nologin olduser
sudo passwd -S olduser
getent passwd olduser
```

These checks distinguish account state, server authorization and live authentication. Preserve the permitted key login while proving each forbidden method fails.

## Common pitfalls

> [!WARNING]
> A connection timeout or a stopped server is not proof of an authentication restriction. Keep the positive administrator test, use fresh sessions, and inspect the reason for each denied connection. Do not edit the VM's port-22 access configuration.
