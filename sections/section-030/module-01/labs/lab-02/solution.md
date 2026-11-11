---
draft: true
---
# Solution

Inside the VM, add the narrow input restriction:

```sh
sudo nft 'add rule inet training input iifname "lab-untrusted" tcp dport 8080 reject with tcp reset'
```

Repeat all four client-to-service requests. Only untrusted access to port 8080 must fail. The host loopback request to that port must still succeed.
