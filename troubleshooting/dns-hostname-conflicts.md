# DNS Resolution Failures and mDNS Hostname Conflicts

## Symptom

A node intermittently loses DNS resolution while the underlying link stays up:

```
$ ping google.com
ping: google.com: Temporary failure in name resolution

$ ping <campus-domain>
PING <campus-domain> (<resolved-ip>) 56(84) bytes of data.
^C
--- ping statistics ---
5 packets transmitted, 0 received, 100% packet loss
```

Pinging a raw IP (e.g. a public resolver like 9.9.9.9) works fine - this isolates the problem to DNS resolution, not routing or the physical link.

## Diagnosis steps

```bash
# What DNS servers does the resolver think it's using?
resolvectl status | grep -A5 "DNS Servers\|DNS Domain\|Current DNS"

# Is avahi/mDNS reporting a hostname conflict on the local segment?
journalctl -u avahi-daemon | grep -i "conflict"
journalctl -u avahi-daemon | grep -i "retrying with"   # avahi appends -2, -3 etc. on conflict

# Does resolv.conf / systemd-resolved / NetworkManager agree with each other?
cat /etc/resolv.conf
journalctl -u systemd-resolved -n 100
journalctl -u NetworkManager | grep -i dns
```

The full collection script used for this is ../scripts/collect-dns-diagnostics.sh - it bundles all of the above into one diagnostic dump.

## What was actually happening

Two DGX Spark nodes with similar factory-default hostnames on the same campus subnet triggered an mDNS/Avahi hostname collision: when two devices advertise the same .local name, Avahi auto-renames the loser to hostname-2.local, and any client (or the node itself, briefly) caching the old name gets stale/failing resolution until the cache clears or the client is told about the new name.

Separately, NetworkManager state logs showed brief CONNECTED_GLOBAL -> CONNECTED_SITE -> CONNECTED_GLOBAL flaps (roughly 1 second) around the same time - worth checking for this pattern independently, since a site-only state means the default route / DNS-capable path was briefly down even though the link stayed up.

## Fix

1. Give every node a unique, explicit hostname before joining the network - don't rely on factory defaults, which are prone to colliding across units purchased in the same batch.
2. Re-check avahi-resolve --name $(hostname).local after any hostname change to confirm there's no lingering -2 suffix being advertised.
3. If DNS servers are being learned inconsistently across interfaces (e.g. a wired campus NIC and a secondary/backup NIC both proposing different resolvers), pin the DNS servers explicitly in the persistent network profile rather than letting DHCP arbitrate.
