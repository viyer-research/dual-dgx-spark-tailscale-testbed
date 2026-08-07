# Offline Driver Install, and a Checkpoint-Interval Lesson

## Installing a kernel module package with no network path

If a node temporarily has no working network route (see dns-hostname-conflicts.md) but you need a kernel module package, download it on a different machine and transfer via USB:

```bash
# On a machine with working internet:
wget "http://ports.ubuntu.com/ubuntu-ports/pool/main/l/linux-nvidia-<version>/<package>.deb"
# Transfer via USB, then on the target node:
sudo dpkg -i <package>.deb
```

Adjust the URL/package name to match the exact kernel version reported by uname -r on the target node - installing a mismatched linux-modules-extra package will not resolve the missing module.

## Lesson: always set --save-every on multi-day runs

Real decision point hit during this deployment, roughly halfway through a ~4-day training run with no crash-resilience checkpointing configured:

- The run had been stable for 46 hours (no NCCL errors, no OOM, no driver issues).
- Killing and restarting with proper checkpointing would have meant losing the 50% already-completed progress - effectively doubling the total time investment just to add safety for the remainder.
- Decision made: let the run finish, since the stability track record didn't justify the restart cost - but flag it so it doesn't happen again.

Takeaway: add --save-every=<N> (or your framework's equivalent) to the launch command in your runbook before starting any multi-day run, not after you're already halfway through one. The cost of a mid-run checkpoint is a few seconds every N steps; the cost of not having one is potentially days of recomputation if anything goes wrong in the final hours.
