#!/usr/bin/env bash
# Collects DNS / mDNS / hostname-conflict diagnostics into dgx_dns_diagnostic.txt
# Usage: ./collect-dns-diagnostics.sh
set -uo pipefail

{
  echo "=== resolv.conf ==="
  cat /etc/resolv.conf

  echo "=== resolvectl status ==="
  resolvectl status

  echo "=== systemd-resolved logs ==="
  journalctl -u systemd-resolved -n 100

  echo "=== avahi-daemon logs ==="
  journalctl -u avahi-daemon -n 100

  echo "=== NetworkManager DNS ==="
  journalctl -u NetworkManager | grep -i dns

  echo "=== HOSTNAME CONFLICT CHECK ==="
  journalctl -u avahi-daemon | grep -i "conflict"

  echo "=== CURRENT ADVERTISED HOSTNAME ==="
  avahi-resolve --name "$(hostname).local" 2>&1

  echo "=== ALL mDNS HOSTNAME SUFFIXES (conflict indicators) ==="
  journalctl -u avahi-daemon | grep -i "retrying with"

  echo "=== NETWORK INTERFACES (conflict source check) ==="
  ip link show

} > dgx_dns_diagnostic.txt

echo "Wrote dgx_dns_diagnostic.txt"
