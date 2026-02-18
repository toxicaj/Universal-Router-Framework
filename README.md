🔥 Universal Router Framework

A powerful, flexible, and dynamic networking utility that transforms WSL2 into a customizable router and VPN pivot engine.

This tool enables seamless traffic forwarding between:

🪟 Windows Host

🐧 WSL2

🔐 VPN (tun interfaces)

🖥 VMware / custom interfaces

🌐 Target lab networks

Designed for CTF labs, red team simulations, VPN pivoting, and controlled network testing environments.

🧠 What This Tool Does

The script enables IP forwarding inside WSL2 and dynamically configures iptables rules to route traffic between interfaces.

It automatically:

Detects active VPN interface (tunX)

Detects LAN interface

Calculates network CIDR

Converts subnet mask automatically

Generates required Windows route add and route delete commands

Typical Pivot Flow:

Windows → WSL (eth0) → VPN (tun0) → Target Network

🚀 Features
Core Routing

✅ NAT forwarding mode

🌉 Bridge mode

🎯 Port-specific forwarding (TCP/UDP)

🔁 One-to-all interface forwarding

🔄 All-to-one interface forwarding

🔥 Full mesh forwarding (lab mode)

Network Support

🔍 Automatic VPN (tun) detection

📡 Broadcast support

📡 Multicast support

🖥 VMware interface compatibility

🌐 Custom interface selection

Windows Integration

🪟 Auto-generated Windows route commands

➕ Route add command

➖ Route delete command

Utility

🧹 Clean stop (reset iptables + disable forwarding)

📋 Interface listing

🎨 Clean colorful CLI output

🛠 Requirements
System Requirements

WSL2

Linux distribution (Kali/Ubuntu recommended)

Windows 10/11

Active VPN connection (if pivoting)

Python3 (for subnet calculation)

iptables (default in most distros)

Windows Requirements

Administrator privileges (to add route)

📦 Installation

Save the script as:

router.sh


Make it executable:

chmod +x router.sh


Place it inside your tools directory.

🚀 How To Use (Step-by-Step Guide)
🔐 Step 1 – Connect VPN inside WSL

Example:

sudo openvpn file.ovpn


Verify:

ip a


Ensure:

tun0 exists

🔁 Step 2 – Start Forwarding
Most Common Use Case (VPN Pivot)
./forward.sh start --in eth0 --out tun0


OR bridge mode:

./forward.sh start --in eth0 --out tun0 --bridge


⚠ Direction Rule:

--in  = LAN side (Windows → eth0)
--out = VPN side (tun0)


Never reverse it.

🪟 Step 3 – Add Windows Route

Script will automatically show something like:

route add 10.8.0.0 mask 255.255.0.0 172.28.90.229 -p


Open Windows CMD as Administrator and paste it.

Verify:

route print

🌐 Step 4 – Test Access

From Windows:

ping <target-ip>


Then open in browser:

http://<target-ip>

🎯 Usage Examples
🔥 Normal VPN Pivot
./forward.sh start --in eth0 --out tun0

🌉 Bridge Mode
./forward.sh start --in eth0 --out tun0 --bridge

🎯 Forward Specific Port
./forward.sh start --in eth0 --out tun0 --port 80 --proto tcp

🌐 Forward One Interface To All
./forward.sh start --forward-all-from eth0

🔄 Forward All To One
./forward.sh start --forward-all-to tun0

🔥 Full Mesh Mode (Lab Only)
./forward.sh start --mesh

📡 Enable Broadcast
./forward.sh start --in eth0 --out tun0 --broadcast

🧹 Stop & Clean Everything
./forward.sh stop


Then remove Windows route:

route delete <network>

🔎 Troubleshooting
Site Not Opening?

Check:

sudo tcpdump -i tun0


Then ping from Windows.

If packets appear → routing works
If no packets → Windows route issue

Common Problems

❌ Direction reversed (--in tun0 --out eth0)

❌ Windows firewall blocking

❌ Wrong subnet added

❌ Route already exists

❌ VPN pushing conflicting routes

❌ WSL2 NAT conflict

⚠ Security Notice

This tool is intended for:

Authorized lab environments

Educational purposes

Controlled red team simulations

Do not use in unauthorized networks.

🏗 Architecture Overview
Windows
   ↓
WSL (eth0)
   ↓
iptables forwarding
   ↓
VPN (tun0)
   ↓
Target Network

📌 Summary

The Universal Router Framework provides:

Dynamic interface forwarding

Automatic route generation

VPN pivot capability

Flexible routing modes

Lab-focused network experimentation

It simplifies WSL-based pivoting setups into a single command workflow.
