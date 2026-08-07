# Management-NIC RX Buffer Saturation (Realtek r8127)

## Symptom

The campus-facing management NIC on a DGX Spark node (Realtek r8127 driver, not the NVIDIA training fiber NIC) shows a growing count of missed RX packets under sustained load, observed live:

```
RX Missed: 524,227 -> 524,409 in ~2 seconds (climbing)
RX Mcast:  595,251 -> 595,387
```

## Diagnosis

```bash
ethtool -g <management_iface>       # ring buffer sizes
ethtool -S <management_iface>       # live RX/TX error, drop, and "missed" counters
ethtool -i <management_iface>       # driver + firmware version
```

Findings from this deployment:

- RX ring buffer was already at hardware maximum (1024) - attempting to raise it further failed at the driver/kernel level (netlink error: requested ring size exceeds maximum).
- No firmware was loaded for the NIC (firmware-version field blank in ethtool -i).
- The missed-packet counter climbs under load but RX/TX errors and drops stay at zero - this specific counter reflects the NIC's hardware descriptor ring filling faster than the driver can service it, not a wiring/link-layer fault.
- apt showed an available kernel-module package older than the currently running kernel - do not blindly apt upgrade in this state; it risks an unintended kernel/driver downgrade. Confirm the target version is actually newer before upgrading.

## When this matters vs. when it doesn't

This NIC carries management/remote-access traffic only in this deployment (Tailscale, SSH, campus connectivity) - it is not in the NCCL data path (see ../docs/dual-node-training-network.md, which uses a separate dedicated fiber NIC). Missed packets here degrade SSH/monitoring responsiveness under load, not training throughput. Don't spend debugging time here assuming it's a training bottleneck - check which physical interface is actually saturated before investigating further.

## Open questions worth asking the vendor

If you hit this, worth escalating to NVIDIA/DGX support directly:

1. Is this Realtek NIC the intended primary management interface, or a secondary one that shouldn't be under this much load?
2. Is there a known RX-buffer saturation issue with this driver under sustained AI/HPC-adjacent workloads (e.g. heavy monitoring/SSH traffic during training)?
3. Is a newer OTA/driver release available that addresses it?
4. What's the safe upgrade path given an inconsistent apt repo state (older package available than currently running)?
