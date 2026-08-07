# Network Architecture

Two networking planes are kept physically and logically separate. Mixing them (e.g. routing NCCL traffic over the management network, or vice versa) is the single most common source of confusing failures in this kind of deployment - see troubleshooting/ for real examples.

```
Compute plane (NCCL / DDP training traffic)
  Node A (rank 0, <NODE_A_TRAINING_IP>)  <-- 200 Gb/s QSFP56 direct fiber, MTU 9000, subnet <TRAINING_SUBNET> -->  Node B (rank 1, <NODE_B_TRAINING_IP>)

Remote-access plane (Tailscale mesh VPN)
  Tailscale VPN (single tailnet)
    |-- Admin devices        (<ADMIN_TAILSCALE_IP>)
    |-- Home / off-site devices
    |-- Student lab PCs      (tag:lab-students)
    |-- DGX Spark nodes      (tag:lab-dgx)  -- same physical nodes as Node A / Node B above, reached via a second NIC
```

## Compute plane (training network)

- Dedicated point-to-point QSFP56 fiber link between the two DGX Spark nodes.
- - Non-routable, private subnet (placeholder: <TRAINING_SUBNET>, e.g. 192.168.100.0/24).
  - - Jumbo frames, MTU 9000, validated with a non-fragmenting 8,972-byte ping payload before every training run.
    - - ethtool should confirm full duplex at the link's rated speed - a driver or cabling issue often shows up as a negotiated speed mismatch here before it shows up in NCCL.
      - - NCCL is explicitly bound to this interface (NCCL_SOCKET_IFNAME=<training_iface>) so it never accidentally selects the management NIC or Tailscale's virtual interface.
       
        - ## Remote-access plane (Tailscale)
       
        - - Every device that needs to reach the cluster - admin laptops, the PI's home machine, student lab PCs, the DGX nodes themselves - joins one Tailscale tailnet.
          - - Devices get a stable 100.x.y.z Tailscale IP that does not change even if the underlying campus DHCP lease does. Students and scripts should always target the Tailscale IP, never the local wired/WiFi IP.
            - - ACL tags scope access (see tailscale-remote-access.md) so a student device can reach the DGX nodes it's meant to, and nothing else.
              - - See dual-node-training-network.md for how this plane stays out of the way of NCCL traffic.
               
                - ## Campus network notes (site-specific, generalize as needed)
               
                - If your institution's network enforces MAC-based access control (a common setup on university campus networks), any container or VM bridged directly onto the campus network will have its traffic silently dropped because its virtual MAC isn't registered. Two ways around this, both used in this deployment at different points:
               
                - 1. NAT bridge on the host. Give the physical host a bridge with a private subnet for VMs/containers (e.g. <PRIVATE_SUBNET> on a bridge like vmbr1 in Proxmox), and let the host's trusted physical NIC MAC do NAT/masquerade for outbound traffic. Containers never present their own MAC to the campus switch.
                  2. 2. Tailscale on the node itself, which tunnels over whatever local connectivity is available and sidesteps campus MAC filtering entirely for remote-access purposes (it doesn't need the campus network to treat it as a first-class device).
                    
                     3. Do not assign DHCP to a private NAT bridge - always use static IPs for containers/VMs on it, since there's intentionally no DHCP server there.
