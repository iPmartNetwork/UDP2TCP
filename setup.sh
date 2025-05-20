#!/usr/bin/env bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

function print_header() {
    clear
    echo -e "${CYAN}=============================================="
    echo -e "    WireGuard UDP over TCP Tunnel Manager"
    echo -e "==============================================${NC}"
}

function check_socat() {
    if ! command -v socat >/dev/null 2>&1; then
        echo -e "${RED}[ERROR]${NC} socat is not installed! Please run: sudo apt install socat"
        exit 1
    fi
}

function server_outside() {
    print_header
    echo -e "${YELLOW} [Server (Outside Iran) Mode]${NC}"
    read -p " 1) Enter UDP port for WireGuard (default 51820): " UDP_PORT
    UDP_PORT=${UDP_PORT:-51820}
    read -p " 2) Enter TCP port for tunnel (default 587): " TCP_PORT
    TCP_PORT=${TCP_PORT:-587}

    echo -e "${GREEN}[INFO]${NC} Starting UDP2TCP server: TCP:$TCP_PORT → UDP:$UDP_PORT"
    echo -e "${CYAN}Press CTRL+C to stop${NC}"

    check_socat

    while true; do
        socat -d tcp-l:$TCP_PORT,reuseaddr,keepalive,fork UDP4:127.0.0.1:$UDP_PORT
        echo -e "${YELLOW}[WARN] socat crashed, restarting in 2s...${NC}"
        sleep 2
    done
}

function server_iran() {
    print_header
    echo -e "${YELLOW} [Server (Inside Iran) Mode]${NC}"
    read -p " 1) Enter public IP or domain of outside server: " OUTSIDE_IP
    read -p " 2) Enter TCP port of tunnel on outside server (default 587): " OUTSIDE_TCP
    OUTSIDE_TCP=${OUTSIDE_TCP:-587}
    read -p " 3) Enter UDP port for local WireGuard (default 51820): " LOCAL_UDP
    LOCAL_UDP=${LOCAL_UDP:-51820}

    echo -e "${GREEN}[INFO]${NC} Starting UDP2TCP client: UDP:$LOCAL_UDP → $OUTSIDE_IP:$OUTSIDE_TCP (TCP)"
    echo -e "${CYAN}Press CTRL+C to stop${NC}"

    check_socat

    while true; do
        socat -d -t600 -T600 UDP4-LISTEN:$LOCAL_UDP tcp4:$OUTSIDE_IP:$OUTSIDE_TCP,keepalive
        echo -e "${YELLOW}[WARN] socat crashed, restarting in 2s...${NC}"
        sleep 2
    done
}

function main_menu() {
    while true; do
        print_header
        echo -e "${GREEN} Select your mode:${NC}"
        echo -e "  1) ${YELLOW}Server (Outside Iran)${NC}  - [UDP → TCP]"
        echo -e "  2) ${YELLOW}Server (Inside Iran)${NC}   - [TCP → UDP]"
        echo -e "  0) Exit"
        echo
        read -p " Enter your choice [0-2]: " mode

        case "$mode" in
            1) server_outside ;;
            2) server_iran ;;
            0) exit 0 ;;
            *) echo -e "${RED}Invalid choice!${NC}"; sleep 1 ;;
        esac
    done
}

# Start menu
main_menu
