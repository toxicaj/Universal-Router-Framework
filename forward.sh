#!/bin/bash

# ================= COLORS =================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ================= DEFAULTS =================
IN_IF=""
OUT_IF=""
PORT=""
PROTO="tcp"
FORWARD_ALL_FROM=""
FORWARD_ALL_TO=""
EXCLUDE_IF=""
MESH_MODE=false
BRIDGE_MODE=false
BROADCAST_MODE=false
MULTICAST_MODE=false
VMWARE_MODE=false
ALL_FORWARD=false

print_line() {
    echo -e "${BLUE}============================================================${NC}"
}

# ================= LIST INTERFACES =================
list_ifaces() {
    print_line
    echo -e "${CYAN}🌐 Available Interfaces:${NC}"
    ip -o link show | awk -F': ' '{print "   ➜ "$2}'
    print_line
    exit 0
}

# ================= AUTO WINDOWS ROUTE =================
auto_windows_route() {

    # Detect VPN interface
    if [[ "$IN_IF" == tun* ]]; then
        VPN_IF="$IN_IF"
        LAN_IF="$OUT_IF"
    elif [[ "$OUT_IF" == tun* ]]; then
        VPN_IF="$OUT_IF"
        LAN_IF="$IN_IF"
    else
        VPN_IF=$(ip -o link show | awk -F': ' '{print $2}' | grep '^tun' | head -n1)
        LAN_IF=$(ip route | awk '/default/ {print $5; exit}')
    fi

    [ -z "$VPN_IF" ] && {
        echo -e "${YELLOW}ℹ️ No VPN interface detected → Windows route not required.${NC}"
        return
    }

    [ -z "$LAN_IF" ] && LAN_IF=$(ip route | awk '/default/ {print $5; exit}')

    WSL_IP=$(ip -4 addr show "$LAN_IF" | awk '/inet /{print $2}' | cut -d/ -f1)
    TUN_CIDR=$(ip -4 addr show "$VPN_IF" | awk '/inet /{print $2}' | head -n1)

    [ -z "$TUN_CIDR" ] && return

    CIDR_MASK=$(echo "$TUN_CIDR" | cut -d'/' -f2)

    SUBNET_MASK=$(python3 - <<EOF
import ipaddress
print(ipaddress.IPv4Network("0.0.0.0/$CIDR_MASK").netmask)
EOF
)

    TARGET_NET=$(python3 - <<EOF
import ipaddress
net = ipaddress.IPv4Network("$TUN_CIDR", strict=False)
print(net.network_address)
EOF
)

    print_line
    echo -e "${CYAN}💻 Windows Route Required${NC}"
    print_line
    echo -e "${GREEN}➕ Add (PowerShell Admin):${NC}"
    echo -e "${YELLOW}route add $TARGET_NET mask $SUBNET_MASK $WSL_IP -p${NC}"
    echo ""
    echo -e "${RED}➖ Delete:${NC}"
    echo -e "${YELLOW}route delete $TARGET_NET${NC}"
    print_line
}

# ================= START FORWARDING =================
start_forwarding() {

    print_line
    echo -e "${CYAN}🚀 Enabling IP Forwarding...${NC}"
    sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null

    sudo iptables -t nat -F
    sudo iptables -F

    ALL_IFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)

    echo -e "${MAGENTA}🔧 Applying Rules...${NC}"

    # ALL FORWARD
    if $ALL_FORWARD; then
        sudo iptables -A FORWARD -j ACCEPT
        sudo iptables -t nat -A POSTROUTING -j MASQUERADE
        echo -e "${GREEN}🔥 ALL TRAFFIC FORWARD ENABLED${NC}"
    fi

    # BRIDGE MODE
    if $BRIDGE_MODE && [ -n "$IN_IF" ] && [ -n "$OUT_IF" ]; then
        sudo iptables -A FORWARD -i "$IN_IF" -o "$OUT_IF" -j ACCEPT
        sudo iptables -A FORWARD -i "$OUT_IF" -o "$IN_IF" -j ACCEPT
        sudo iptables -t nat -A POSTROUTING -o "$OUT_IF" -j MASQUERADE
        echo -e "${GREEN}🌉 Bridge Mode Enabled ($IN_IF ↔ $OUT_IF)${NC}"
    fi

    # PORT FORWARD
    if [ -n "$PORT" ] && [ -n "$IN_IF" ] && [ -n "$OUT_IF" ]; then
        sudo iptables -A FORWARD -i "$IN_IF" -o "$OUT_IF" -p "$PROTO" --dport "$PORT" -j ACCEPT
        sudo iptables -t nat -A POSTROUTING -o "$OUT_IF" -p "$PROTO" --dport "$PORT" -j MASQUERADE
        echo -e "${GREEN}🎯 Port Forward $PROTO/$PORT Enabled${NC}"
    fi

    # ONE ➜ ALL
    if [ -n "$FORWARD_ALL_FROM" ]; then
        for iface in $ALL_IFACES; do
            if [ "$iface" != "$FORWARD_ALL_FROM" ] && [ "$iface" != "$EXCLUDE_IF" ]; then
                sudo iptables -A FORWARD -i "$FORWARD_ALL_FROM" -o "$iface" -j ACCEPT
            fi
        done
        echo -e "${GREEN}🌐 $FORWARD_ALL_FROM ➜ ALL${NC}"
    fi

    # ALL ➜ ONE
    if [ -n "$FORWARD_ALL_TO" ]; then
        for iface in $ALL_IFACES; do
            if [ "$iface" != "$FORWARD_ALL_TO" ] && [ "$iface" != "$EXCLUDE_IF" ]; then
                sudo iptables -A FORWARD -i "$iface" -o "$FORWARD_ALL_TO" -j ACCEPT
            fi
        done
        echo -e "${GREEN}🌐 ALL ➜ $FORWARD_ALL_TO${NC}"
    fi

    # MESH
    if $MESH_MODE; then
        for i in $ALL_IFACES; do
            for j in $ALL_IFACES; do
                [ "$i" != "$j" ] && sudo iptables -A FORWARD -i "$i" -o "$j" -j ACCEPT
            done
        done
        sudo iptables -t nat -A POSTROUTING -j MASQUERADE
        echo -e "${GREEN}🔥 FULL MESH MODE ENABLED${NC}"
    fi

    # BROADCAST
    if $BROADCAST_MODE; then
        sudo iptables -A FORWARD -d 255.255.255.255 -j ACCEPT
        echo -e "${GREEN}📡 Broadcast Enabled${NC}"
    fi

    # MULTICAST
    if $MULTICAST_MODE; then
        sudo iptables -A FORWARD -d 224.0.0.0/4 -j ACCEPT
        echo -e "${GREEN}📡 Multicast Enabled${NC}"
    fi

    auto_windows_route
}

# ================= STOP =================
stop_forwarding() {
    print_line
    echo -e "${YELLOW}⛔ Cleaning Rules & Disabling Forwarding...${NC}"
    sudo sysctl -w net.ipv4.ip_forward=0 > /dev/null
    sudo iptables -t nat -F
    sudo iptables -F
    echo -e "${GREEN}✅ All Rules Cleared${NC}"
    print_line
}

# ================= HELP =================
show_help() {
    print_line
    echo -e "${CYAN}🔥 UNIVERSAL ROUTER FRAMEWORK 🔥${NC}"
    print_line
    echo -e "Usage:"
    echo -e "  $0 start [options]"
    echo -e "  $0 stop"
    echo -e "  $0 route"
    echo -e "  $0 --list-ifaces"
    echo ""
    echo -e "--in <iface>  --out <iface>"
    echo -e "--forward-all-from <iface>"
    echo -e "--forward-all-to <iface>"
    echo -e "--mesh  --bridge  --all-forward"
    echo -e "--port <port>  --proto tcp|udp"
    echo -e "--broadcast  --multicast"
    echo -e "--exclude <iface>"
    print_line
    exit 0
}

# ================= ARG PARSE =================
ACTION="$1"
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        --in) IN_IF="$2"; shift 2 ;;
        --out) OUT_IF="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --proto) PROTO="$2"; shift 2 ;;
        --forward-all-from) FORWARD_ALL_FROM="$2"; shift 2 ;;
        --forward-all-to) FORWARD_ALL_TO="$2"; shift 2 ;;
        --exclude) EXCLUDE_IF="$2"; shift 2 ;;
        --mesh) MESH_MODE=true; shift ;;
        --bridge) BRIDGE_MODE=true; shift ;;
        --broadcast) BROADCAST_MODE=true; shift ;;
        --multicast) MULTICAST_MODE=true; shift ;;
        --all-forward) ALL_FORWARD=true; shift ;;
        --list-ifaces) list_ifaces ;;
        --help) show_help ;;
        route) auto_windows_route; exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; show_help ;;
    esac
done

case "$ACTION" in
    start) start_forwarding ;;
    stop) stop_forwarding ;;
    route) auto_windows_route ;;
    *) show_help ;;
esac
