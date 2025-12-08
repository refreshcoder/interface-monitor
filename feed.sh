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
if curl -fsSL "$KEY_URL" -o "$TMPKEY"; then
  if command -v opkg-key >/dev/null 2>&1; then
    opkg-key add "$TMPKEY"
  else
    FP=$(usign -F -p "$TMPKEY")
    if [ -n "$FP" ]; then
      cp "$TMPKEY" "/etc/opkg/keys/$FP"
    else
      echo "Error: Failed to get fingerprint from key"
      exit 1
    fi
  fi
else
  echo "Error: Failed to download key from $KEY_URL"
  exit 1
fi
opkg update
