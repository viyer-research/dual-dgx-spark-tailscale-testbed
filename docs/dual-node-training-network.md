# Dual-Node Training Network (Compute Plane)

This is the NVIDIA direct-fiber link between the two DGX Spark nodes, used exclusively for NCCL/DDP gradient synchronization during distributed training. Kept fully separate from the Tailscale remote-access plane (see tailscale-remote-access.md).

## 1. Persistent link configuration

Hosts may use different Linux network managers (nmcli vs netplan) - check both before configuring. Create a persistent profile with static addresses and MTU 9000 so the link survives reboot (a plain "ip addr add" does not).

```bash
# Example with nmcli - adapt interface name and IPs to your hardware
sudo nmcli connection add type ethernet ifname <TRAINING_IFACE> con-name dgx-training-link \
  ipv4.addresses <NODE_IP>/24 ipv4.method manual \
  802-3-ethernet.mtu 9000

sudo nmcli connection up dgx-training-link
```

Validate the link before every training run:

```bash
# Bidirectional connectivity
ping -c 5 <PEER_TRAINING_IP>

# Confirm full duplex at rated speed
sudo ethtool <TRAINING_IFACE> | grep -i speed

# Confirm jumbo frames are actually passing end to end
ping -M do -s 8972 -c 3 <PEER_TRAINING_IP>
```

## 2. Container configuration

Host networking is required so the container can see the physical training NIC directly (bridged/NAT networking will not expose it).

```bash
docker run --gpus all -it --rm \
  --ulimit memlock=-1 --ulimit stack=67108864 \
  --network host \
  -v <CACHE_DIR>:/root/.cache/nanochat \
  -v <REPO_DIR>:/workspace/nanochat \
  nvcr.io/nvidia/pytorch:25.10-py3 bash
```

## 3. NCCL environment

Bind NCCL explicitly to the training interface so it can never fall back to the management NIC or a VPN virtual interface:

```bash
export NCCL_SOCKET_IFNAME=<TRAINING_IFACE>
export NCCL_TIMEOUT=3600
export TORCH_NCCL_BLOCKING_WAIT=1
export WANDB_MODE=disabled
```

## 4. Launch (two nodes, one process per node)

```bash
# Rank 0
torchrun --nproc_per_node=1 --nnodes=2 --node_rank=0 \
  --master_addr=<NODE0_TRAINING_IP> --master_port=29501 \
  -m scripts.base_train -- \
  --depth=20 --device-batch-size=32 \
  --run=<RUN_NAME> --save-every=500

# Rank 1 - identical, with --node_rank=1
```

Run both inside tmux so training survives an SSH/Tailscale disconnect. Only rank 0 typically logs step/loss output - confirm rank 1 is alive via nvidia-smi and process memory, not log silence.

save-every matters. A default "save only at the end" checkpoint policy is not acceptable for multi-day runs - see ../troubleshooting/ for what happens when a long run has no mid-run checkpoint and something goes wrong at hour 40.

## 5. Known step-zero timeout issue

An unguarded evaluation call at step zero (step % args.eval_every == 0, without a step > 0 guard) can trigger a slow bits-per-byte evaluation before training even starts, which then trips the NCCL watchdog on multi-node launches. Fix:

```python
# before
if step % args.eval_every == 0:
    ...

# after
if step % args.eval_every == 0 and step > 0:
    ...
```

This is a local patch against the upstream training script and must be reapplied on a fresh clone.
