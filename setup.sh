#!/usr/bin/env bash

# ==========================
#   WireGuard UDP-over-TCP Tunnel Manager
#   - Auto socat install
#   - Auto systemd service
#   - Color menu, Persian/English
# ==========================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${CYAN}=============================================="
    echo -e "    WireGuard UDP over TCP Tunnel Manager"
    echo -e "==============================================${NC}"
}

install_socat() {
    if command -v socat >/dev/null 2>&1; then
        return
    fi
    echo -e "${YELLOW}[INFO] Installing socat ...${NC}"
    if [ -f /etc/debian_version ]; then
        sudo apt update
        sudo apt install -y socat
    elif [ -f /etc/redhat-release ]; then
        sudo yum install -y socat || sudo dnf install -y socat
    else
        echo -e "${RED}[ERROR] Unknown Linux distribution. Please install socat manually.${NC}"
        exit 1
    fi
}

write_server_service() {
    cat <<EOF | sudo tee /etc/systemd/system/udp2tcp-server-$2.service >/dev/null
[Unit]
Description=UDP2TCP Tunnel Server (WireGuard UDP over TCP)
After=network.target

[Service]
Type=simple
ExecStart=$PWD/$0 run_server $1 $2
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now udp2tcp-server-$2
    echo -e "${GREEN}Service 'udp2tcp-server-$2' started!${NC}"
}

write_client_service() {
    cat <<EOF | sudo tee /etc/systemd/system/udp2tcp-client-$3.service >/dev/null
[Unit]
Description=UDP2TCP Tunnel Client (WireGuard UDP over TCP)
After=network.target

[Service]
Type=simple
ExecStart=$PWD/$0 run_client $1 $2 $3
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now udp2tcp-client-$3
    echo -e "${GREEN}Service 'udp2tcp-client-$3' started!${NC}"
}

run_server_mode() {
    print_header
    echo -e "${YELLOW} [Server (Outside Iran) Mode]${NC}"
    read -p " 1) Enter UDP port for WireGuard (default 51820): " UDP_PORT
    UDP_PORT=${UDP_PORT:-51820}
    read -p " 2) Enter TCP port for tunnel (default 587): " TCP_PORT
    TCP_PORT=${TCP_PORT:-587}

    echo -e "${GREEN}How do you want to run the tunnel?${NC}"
    echo "  1) Temporary (directly in this terminal)"
    echo "  2) Permanent (as a systemd service, auto-start on reboot)"
    read -p " Your choice [1-2]: " servopt

    if [ "$servopt" == "2" ]; then
        write_server_service "$UDP_PORT" "$TCP_PORT"
        echo -e "${CYAN}You can check status via:${NC} sudo systemctl status udp2tcp-server-$TCP_PORT"
        echo -e "${CYAN}To stop:${NC} sudo systemctl stop udp2tcp-server-$TCP_PORT"
        exit 0
    else
        echo -e "${GREEN}[INFO]${NC} Starting UDP2TCP server: TCP:$TCP_PORT → UDP:$UDP_PORT"
        echo -e "${CYAN}Press CTRL+C to stop${NC}"
        while true; do
            socat -d tcp-l:$TCP_PORT,reuseaddr,keepalive,fork UDP4:127.0.0.1:$UDP_PORT
            echo -e "${YELLOW}[WARN] socat crashed, restarting in 2s...${NC}"
            sleep 2
        done
    fi
}

run_client_mode() {
    print_header
    echo -e "${YELLOW} [Server (Inside Iran) Mode]${NC}"
    read -p " 1) Enter public IP or domain of outside server: " OUTSIDE_IP
    read -p " 2) Enter TCP port of tunnel on outside server (default 587): " OUTSIDE_TCP
    OUTSIDE_TCP=${OUTSIDE_TCP:-587}
    read -p " 3) Enter UDP port for local WireGuard (default 51820): " LOCAL_UDP
    LOCAL_UDP=${LOCAL_UDP:-51820}

    echo -e "${GREEN}How do you want to run the tunnel?${NC}"
    echo "  1) Temporary (directly in this terminal)"
    echo "  2) Permanent (as a systemd service, auto-start on reboot)"
    read -p " Your choice [1-2]: " servopt

    if [ "$servopt" == "2" ]; then
        write_client_service "$OUTSIDE_IP" "$OUTSIDE_TCP" "$LOCAL_UDP"
        echo -e "${CYAN}You can check status via:${NC} sudo systemctl status udp2tcp-client-$LOCAL_UDP"
        echo -e "${CYAN}To stop:${NC} sudo systemctl stop udp2tcp-client-$LOCAL_UDP"
        exit 0
    else
        echo -e "${GREEN}[INFO]${NC} Starting UDP2TCP client: UDP:$LOCAL_UDP → $OUTSIDE_IP:$OUTSIDE_TCP (TCP)"
        echo -e "${CYAN}Press CTRL+C to stop${NC}"
        while true; do
            socat -d -t600 -T600 UDP4-LISTEN:$LOCAL_UDP tcp4:$OUTSIDE_IP:$OUTSIDE_TCP,keepalive
            echo -e "${YELLOW}[WARN] socat crashed, restarting in 2s...${NC}"
            sleep 2
        done
    fi
}

# For systemd (internal run mode, do not use directly)
if [[ "$1" == "run_server" ]]; then
    install_socat
    UDP_PORT="$2"
    TCP_PORT="$3"
    while true; do
        socat -d tcp-l:$TCP_PORT,reuseaddr,keepalive,fork UDP4:127.0.0.1:$UDP_PORT
        sleep 2
    done
    exit 0
elif [[ "$1" == "run_client" ]]; then
    install_socat
    OUTSIDE_IP="$2"
    OUTSIDE_TCP="$3"
    LOCAL_UDP="$4"
    while true; do
        socat -d -t600 -T600 UDP4-LISTEN:$LOCAL_UDP tcp4:$OUTSIDE_IP:$OUTSIDE_TCP,keepalive
        sleep 2
    done
    exit 0
fi

# Main menu
install_socat
while true; do
    print_header
    echo -e "${GREEN} Select your mode:${NC}"
    echo -e "  1) ${YELLOW}Server (Outside Iran)${NC}  - [UDP → TCP]"
    echo -e "  2) ${YELLOW}Server (Inside Iran)${NC}   - [TCP → UDP]"
    echo -e "  0) Exit"
    echo
    read -p " Enter your choice [0-2]: " mode

    case "$mode" in
        1) run_server_mode ;;
        2) run_client_mode ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid choice!${NC}"; sleep 1 ;;
    esac
done
