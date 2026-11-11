---
draft: true
---
# Solution

Run these commands inside the VM. They modify only the training listener.

```sh
sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin no/;s/^PasswordAuthentication .*/PasswordAuthentication no/;s/^AllowUsers .*/AllowUsers opsadmin/' /etc/ssh/sshd_config.training
sudo usermod -L -s /usr/sbin/nologin olduser
sudo /usr/sbin/sshd -t -f /etc/ssh/sshd_config.training
sudo systemctl reload training-sshd
sleep 1
```

Then test a fresh opsadmin key login and the denied root, password and olduser logins described in the task. Keep the administrator connection working.
