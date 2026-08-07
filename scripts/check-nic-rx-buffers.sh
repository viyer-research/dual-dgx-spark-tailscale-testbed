#!/usr/bin/env bash
# Checks RX ring buffer usage and missed-packet counters for a given interface.
# Usage: ./check-nic-rx-buffers.sh <interface>
set -euo pipefail

IFACE="${1:?Usage: $0 <interface>}"

echo "=== Driver info ==="
ethtool -i "$IFACE"

echo
echo "=== Ring buffer sizes (pre-set max vs current) ==="
ethtool -g "$IFACE"

echo
echo "=== Live stats snapshot 1 ==="
ethtool -S "$IFACE" | grep -Ei "rx_missed|rx_mcast|rx_errors|rx_dropped|tx_errors|tx_dropped"

sleep 2

echo
echo "=== Live stats snapshot 2 (2s later - compare deltas) ==="
ethtool -S "$IFACE" | grep -Ei "rx_missed|rx_mcast|rx_errors|rx_dropped|tx_errors|tx_dropped"

echo
echo "If rx_missed is climbing between snapshots while rx_errors/rx_dropped stay flat,"
echo "the NIC's descriptor ring is filling faster than the driver services it under load."
echo "See troubleshooting/nic-rx-buffer-saturation.md"
