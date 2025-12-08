#!/bin/bash
set -euo pipefail

[ ! -d ./scripts ] && ./setup.sh
./scripts/feeds update -a
./scripts/feeds install -a

[ -d /src/interface-monitor ] && cp -r /src/interface-monitor package/
[ -d /src/luci-app-interface-monitor ] && cp -r /src/luci-app-interface-monitor package/

echo "CONFIG_PACKAGE_interface-monitor=m" >> .config
echo "CONFIG_PACKAGE_luci-app-interface-monitor=m" >> .config
make defconfig

make package/{interface-monitor,luci-app-interface-monitor}/compile -j$(nproc) V=s || exit 1

chmod 777 /src/bin_output || true
ARCH_DIR="${ARCH_TAG:-x86_64}"
BASE_DIR="/src/bin_output/openwrt-24.10/${ARCH_DIR}/interface-monitor"
mkdir -p "$BASE_DIR"

find bin/packages -name "interface-monitor*.ipk" -exec cp -v {} "$BASE_DIR/" \;
find bin/packages -name "luci-app-interface-monitor*.ipk" -exec cp -v {} "$BASE_DIR/" \;

if ! command -v sha256sum >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then apt-get update && apt-get install -y coreutils busybox || true
  elif command -v apk >/dev/null 2>&1; then apk add --no-cache coreutils busybox || true
  elif command -v dnf >/dev/null 2>&1; then dnf install -y coreutils busybox || true
  elif command -v yum >/dev/null 2>&1; then yum install -y coreutils busybox || true
  fi
fi
if ! command -v ar >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then apt-get update && apt-get install -y binutils || true
  elif command -v apk >/dev/null 2>&1; then apk add --no-cache binutils || true
  elif command -v dnf >/dev/null 2>&1; then dnf install -y binutils || true
  elif command -v yum >/dev/null 2>&1; then yum install -y binutils || true
  fi
fi
if ! command -v sha256sum >/dev/null 2>&1; then if command -v busybox >/dev/null 2>&1; then ln -sf "$(command -v busybox)" /usr/bin/sha256sum; fi; fi
if ! command -v md5sum >/dev/null 2>&1; then if command -v busybox >/dev/null 2>&1; then ln -sf "$(command -v busybox)" /usr/bin/md5sum; fi; fi
if ! command -v sha256 >/dev/null 2>&1; then if command -v sha256sum >/dev/null 2>&1; then ln -sf "$(command -v sha256sum)" /usr/bin/sha256; fi; fi

ipk_count=$(ls -1 "$BASE_DIR"/*.ipk 2>/dev/null | wc -l || echo 0)
ls -la "$BASE_DIR"
if [ "$ipk_count" -eq 0 ]; then
  exit 2
fi

if [ -x ./scripts/ipkg-make-index.sh ]; then bash ./scripts/ipkg-make-index.sh "$BASE_DIR" > "$BASE_DIR/Packages" || true; else ./scripts/ipkg-make-index.sh "$BASE_DIR" > "$BASE_DIR/Packages" || true; fi

if [ ! -s "$BASE_DIR/Packages" ]; then
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

if [ -s "$BASE_DIR/Packages" ]; then gzip -9c "$BASE_DIR/Packages" > "$BASE_DIR/Packages.gz"; fi

mkdir -p /src/bin_output/openwrt-24.10/keys
if [ -n "${OPKG_SIGNING_PRIV:-}" ]; then
  printf "%s\n" "$OPKG_SIGNING_PRIV" > /tmp/opkg_priv.key
  if [ -n "${OPKG_SIGNING_PUB:-}" ]; then printf "%s\n" "$OPKG_SIGNING_PUB" > /src/bin_output/openwrt-24.10/keys/opkg_pub.key; fi
  if [ -x staging_dir/host/bin/usign ]; then
    staging_dir/host/bin/usign -S -m "$BASE_DIR/Packages" -s /tmp/opkg_priv.key -x "$BASE_DIR/Packages.sig"
  else
    usign -S -m "$BASE_DIR/Packages" -s /tmp/opkg_priv.key -x "$BASE_DIR/Packages.sig"
  fi
fi

ls -la "$BASE_DIR"
