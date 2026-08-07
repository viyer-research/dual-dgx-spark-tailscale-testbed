# Dual DGX Spark + Tailscale: A Remote-Access AI Testbed

Deployment runbook and reproducibility artifacts for a two-node NVIDIA DGX Spark cluster used for distributed LLM training (NanoChat / PyTorch DDP + NCCL) and made remotely accessible to students and admins over a Tailscale mesh VPN.

This repo separates the two networking planes deliberately, because that separation is the core engineering pattern worth reusing:

| Plane | Purpose | Technology |
|---|---|---|
| Compute / training plane | High-throughput NCCL gradient sync between the two DGX Spark nodes | Direct NVIDIA QSFP56 fiber link, 200 Gb/s, MTU 9000 |
| Remote-access / management plane | SSH, admin, and student access to the nodes from anywhere (home, lab, other buildings) without static IPs or VPN hardware | Tailscale mesh VPN, ACL-tagged devices |

Companion research report (distributed training + CTI fine-tuning results): "Dual-Node NVIDIA DGX Spark over Tailscale: A Remote-Access Testbed for Distributed LLM Training and Cyber-Threat-Intelligence Fine-Tuning" (arXiv preprint, included in the parent NSF project report).

## Contents

- [docs/network-architecture.md](docs/network-architecture.md) - physical + logical topology, VLAN/bridge design, both networking planes
- [docs/tailscale-remote-access.md](docs/tailscale-remote-access.md) - tailnet design, ACL tags, why Tailscale (not port-forwarding/campus VPN) solves DHCP churn for a shared lab
- [docs/dual-node-training-network.md](docs/dual-node-training-network.md) - the NVIDIA direct-fiber compute plane: persistent link config, NCCL binding, container launch
- [troubleshooting/](troubleshooting/) - real incidents and fixes: DNS/mDNS hostname conflicts, NIC RX buffer saturation, offline driver install, checkpoint-interval lesson
- [scripts/](scripts/) - diagnostic scripts referenced in the troubleshooting docs

## Hardware summary

- 2x NVIDIA DGX Spark (GB10 Grace Blackwell SoC, 128 GB unified memory each)
- Direct 200 Gb/s QSFP56 fiber between the two nodes (training/NCCL traffic only)
- Tailscale mesh VPN for all remote administration and student SSH access
- PyTorch NGC container (nvcr.io/nvidia/pytorch:25.10-py3), torchrun + DDP + NCCL

## Values redacted in this repo

All real IP addresses, hostnames, MAC addresses, and account/login names from the source deployment have been replaced with placeholders (e.g. <NODE_A_TAILSCALE_IP>, <CAMPUS_SUBNET>) so this can be used as a template on a different network. Substitute your own values throughout.

## License

MIT - see [LICENSE](LICENSE). Attribution appreciated if this runbook saves you a debugging session.
