---
draft: true
---
# Test A Host Firewall With Two Clients

A host firewall decides which packets may reach a listening service. Test it from the client side: a socket bound to all addresses can still be protected by a firewall, while a loopback-only listener does not demonstrate packet filtering.

The independent QEMU lab provides two Linux network namespaces. Each namespace has its own interfaces and routing table, so a request travels through a veth pair into the VM's host input path. Connect with `astrona ssh ats-033-lab-030-01-02` and run the examples inside the VM. The `trusted` client reaches host address `192.0.2.1`; `untrusted` reaches `198.51.100.1`.

<!-- astrona:playground:renew -->

Establish that the service works before adding a restriction:

```sh
sudo ip netns exec trusted curl --max-time 3 http://192.0.2.1:8080/
sudo ip netns exec untrusted curl --max-time 3 http://198.51.100.1:8080/
sudo nft list table inet training
```

The existing input chain uses policy `accept`. An additional rule can reject only a narrow combination of input interface, protocol and destination port. Save this as `restrict-service.nft`:

```text
add rule inet training input iifname "lab-untrusted" tcp dport 8080 reject with tcp reset
```

Check the syntax, then apply it:

```sh
sudo nft -c -f restrict-service.nft
sudo nft -f restrict-service.nft
```

`iifname` matches the receiving interface. `tcp dport` matches the destination port. `reject with tcp reset` closes the TCP attempt promptly; a `drop` rule would instead leave the client waiting until its timeout. This rule does not change the separate service on port 8081.

Repeat the earlier requests, then check the public service from both clients:

```sh
sudo ip netns exec trusted curl --max-time 3 http://192.0.2.1:8081/
sudo ip netns exec untrusted curl --max-time 3 http://198.51.100.1:8081/
curl --max-time 3 http://127.0.0.1:8080/
sudo nft -a list chain inet training input
```

The trusted client must reach both ports. The untrusted client must reach only 8081. The loopback control confirms that the restricted service still runs. Rule handles printed by `-a` let you delete one mistaken rule without flushing unrelated controls.

## Common pitfalls

> [!WARNING]
> Do not flush the VM's whole firewall or change its default input policy. Keep changes within the training table. A blocked request alone is insufficient evidence: prove that the allowed client and the unrelated service still work.
