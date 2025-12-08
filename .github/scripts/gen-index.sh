#!/bin/bash
set -euo pipefail
export LC_ALL=C

# Install indexing dependencies
if command -v apt-get >/dev/null 2>&1; then
  apt-get update && apt-get install -y binutils coreutils tar gzip sed gawk file || true
elif command -v apk >/dev/null 2>&1; then
  apk add --no-cache binutils coreutils tar gzip sed gawk file || true
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y binutils coreutils tar gzip sed gawk file || true
elif command -v yum >/dev/null 2>&1; then
  yum install -y binutils coreutils tar gzip sed gawk file || true
fi

# Link busybox tools if standard ones are missing (fallback)
if ! command -v sha256sum >/dev/null 2>&1; then if command -v busybox >/dev/null 2>&1; then ln -sf "$(command -v busybox)" /usr/bin/sha256sum; fi; fi

ARCH_DIR="${ARCH_TAG:-x86_64}"
BASE_DIR="/src/bin_output/openwrt-24.10/${ARCH_DIR}/interface-monitor"

echo "Checking IPK files in $BASE_DIR:"
ls -la "$BASE_DIR"
file "$BASE_DIR"/*.ipk || true

echo "Generating package index..."
# Try using official SDK script if available
if [ -x ./scripts/ipkg-make-index.sh ]; then 
  if ! bash ./scripts/ipkg-make-index.sh "$BASE_DIR" > "$BASE_DIR/Packages"; then
    echo "Official ipkg-make-index.sh failed, cleaning up empty index."
    rm -f "$BASE_DIR/Packages"
  fi
else
  echo "Official ipkg-make-index.sh not found in $(pwd)"
fi

# Fallback: Manual Index Generation
if [ ! -s "$BASE_DIR/Packages" ]; then
  echo "Generating index using fallback method..."
  TMPIDX="/tmp/pkgidx"; mkdir -p "$TMPIDX"; : > "$BASE_DIR/Packages"
  for f in "$BASE_DIR"/*.ipk; do
    [ -f "$f" ] || continue
    ar p "$f" control.tar.gz > "$TMPIDX/ctrl.tgz" || continue
    tar -xOzf "$TMPIDX/ctrl.tgz" ./control > "$TMPIDX/control" || continue
    size=$(stat -c %s "$f" 2>/dev/null || wc -c < "$f")
    sha=$(sha256sum "$f" | awk '{print $1}')
    grep -E "^Package:|^Version:|^Architecture:|^Description:" "$TMPIDX/control" >> "$BASE_DIR/Packages"
    bn=$(basename "$f")
    printf "Filename: %s\n" "$bn" >> "$BASE_DIR/Packages"
    printf "Size: %s\n" "$size" >> "$BASE_DIR/Packages"
    printf "SHA256sum: %s\n\n" "$sha" >> "$BASE_DIR/Packages"
  done
fi

if [ -s "$BASE_DIR/Packages" ]; then 
  echo "Compressing index..."
  gzip -9c "$BASE_DIR/Packages" > "$BASE_DIR/Packages.gz"
fi

mkdir -p /src/bin_output/openwrt-24.10/keys
if [ -n "${OPKG_SIGNING_PRIV:-}" ]; then
  echo "Signing index..."
  printf "%s\n" "$OPKG_SIGNING_PRIV" > /tmp/opkg_priv.key
  if [ -n "${OPKG_SIGNING_PUB:-}" ]; then printf "%s\n" "$OPKG_SIGNING_PUB" > /src/bin_output/openwrt-24.10/keys/opkg_pub.key; fi
  if [ -x staging_dir/host/bin/usign ]; then
    staging_dir/host/bin/usign -S -m "$BASE_DIR/Packages" -s /tmp/opkg_priv.key -x "$BASE_DIR/Packages.sig"
  else
    if command -v usign >/dev/null 2>&1; then
        usign -S -m "$BASE_DIR/Packages" -s /tmp/opkg_priv.key -x "$BASE_DIR/Packages.sig"
    else
        echo "Warning: usign not found, skipping signature."
    fi
  fi
fi

ls -la "$BASE_DIR"
