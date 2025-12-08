#!/bin/ash
set -e
BASE="https://refreshcoder.github.io/interface-monitor/openwrt-24.10"
ARCH=$(opkg print-architecture | awk '{print $2}' | tail -n1)
URL="$BASE/$ARCH/interface-monitor"
KEY_URL="$BASE/keys/opkg_pub.key"
CFG="/etc/opkg/customfeeds.conf"
mkdir -p /etc/opkg
touch "$CFG"
grep -q "$URL" "$CFG" || echo "src/gz interface-monitor $URL" >> "$CFG"
TMPKEY="/tmp/opkg_pub.key"
curl -fsSL "$KEY_URL" -o "$TMPKEY" || true
if [ -s "$TMPKEY" ]; then
  FP=$(usign -F -p "$TMPKEY" | awk '{print $2}')
  cp "$TMPKEY" "/etc/opkg/keys/$FP"
fi
opkg update
