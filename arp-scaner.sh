#!/bin/bash
#
# ARP-сканер адресов вида PREFIX.SUBNET.HOST (маска /24)
#
# Использование:
#   sudo ./arp_scan.sh PREFIX INTERFACE [SUBNET] [HOST]
#
#   PREFIX INTERFACE               — сканируются все подсети PREFIX.1-255.1-255
#   PREFIX INTERFACE SUBNET        — сканируются все хосты PREFIX.SUBNET.1-255
#   PREFIX INTERFACE SUBNET HOST   — сканируется один адрес PREFIX.SUBNET.HOST

# Регулярное выражение для одного октета: 0..255 (без ведущих нулей)
OCTET_RE='(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])'
PREFIX_RE="^${OCTET_RE}\.${OCTET_RE}$"
SINGLE_OCTET_RE="^${OCTET_RE}$"
INTERFACE_RE='^[a-zA-Z0-9._-]+$'

# ---------- Служебные функции ----------

usage() {
    echo "Usage: sudo $0 PREFIX INTERFACE [SUBNET] [HOST]"
    echo "  PREFIX    - first two octets, e.g. 192.168"
    echo "  INTERFACE - network interface, e.g. eth0"
    echo "  SUBNET    - third octet (0-255), optional"
    echo "  HOST      - fourth octet (0-255), optional, requires SUBNET"
}

die() {
    echo "Error: $1" >&2
    usage >&2
    exit 1
}

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "Error: this script must be run with root privileges (try: sudo $0 ...)" >&2
        exit 1
    fi
}

# validate ИМЯ ЗНАЧЕНИЕ РЕГУЛЯРКА — проверка параметра регулярным выражением
validate() {
    local name="$1" value="$2" regex="$3"
    [[ "$value" =~ $regex ]] || die "\$$name has invalid value: '$value'"
}

# require ИМЯ ЗНАЧЕНИЕ ПОЗИЦИЯ — проверка, что обязательный параметр передан
require() {
    local name="$1" value="$2" position="$3"
    [[ -n "$value" ]] || die "\$$name must be passed as $position positional argument"
}

# ---------- Функции сканирования ----------

# scan_ip SUBNET HOST — сканирование одного адреса
scan_ip() {
    local ip="${PREFIX}.$1.$2"
    echo "[*] IP : ${ip}"
    arping -c 3 -i "$INTERFACE" "$ip" 2> /dev/null
}

# scan_subnet SUBNET — сканирование всех хостов одной подсети
scan_subnet() {
    local host
    for host in {1..255}; do
        scan_ip "$1" "$host"
    done
}

# scan_all — сканирование всех подсетей префикса
scan_all() {
    local subnet
    for subnet in {1..255}; do
        scan_subnet "$subnet"
    done
}

# ---------- Основная логика ----------

check_root

[[ $# -gt 4 ]] && die "too many arguments"

PREFIX="$1"
INTERFACE="$2"
SUBNET="$3"
HOST="$4"

require  PREFIX "$PREFIX" "first"
validate PREFIX "$PREFIX" "$PREFIX_RE"

require  INTERFACE "$INTERFACE" "second"
validate INTERFACE "$INTERFACE" "$INTERFACE_RE"
ip link show "$INTERFACE" &> /dev/null || die "interface '$INTERFACE' does not exist"

[[ -n "$SUBNET" ]] && validate SUBNET "$SUBNET" "$SINGLE_OCTET_RE"
if [[ -n "$HOST" ]]; then
    require  SUBNET "$SUBNET" "third"
    validate HOST "$HOST" "$SINGLE_OCTET_RE"
fi

if [[ -n "$HOST" ]]; then
    scan_ip "$SUBNET" "$HOST"
elif [[ -n "$SUBNET" ]]; then
    scan_subnet "$SUBNET"
else
    scan_all
fi
