#!/bin/bash
set -euo pipefail
export LC_ALL=C

penwrt/gh-action-sdk@main# Install required tools BEFORE build to ensure IPKs are created as ar archives
# Unconditionally install to ensure we have GNU versions instead of busybox/limited ones
if command -v apt-get >/dev/null 2>&1; then
  apt-get update && apt-get install -y binutils coreutils tar sed gawk file || true
elif command -v apk >/dev/null 2>&1; then
  apk add --no-cache binutils coreutils tar sed gawk file || true
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y binutils coreutils tar sed gawk file || true
elif command -v yum >/dev/null 2>&1; then
  yum install -y binutils coreutils tar sed gawk file || true
fi

# Link busybox tools if standard ones are missing (fallback)
if ! command -v sha256sum >/dev/null 2>&1; then if command -v busybox >/dev/null 2>&1; then ln -sf "$(command -v busybox)" /usr/bin/sha256sum; fi; fi
if ! command -v md5sum >/dev/null 2>&1; then if command -v busybox >/dev/null 2>&1; then ln -sf "$(command -v busybox)" /usr/bin/md5sum; fi; fi
if ! command -v sha256 >/dev/null 2>&1; then if command -v sha256sum >/dev/null 2>&1; then ln -sf "$(command -v sha256sum)" /usr/bin/sha256; fi; fi

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

ipk_count=$(ls -1 "$BASE_DIR"/*.ipk 2>/dev/null | wc -l || echo 0)
ls -la "$BASE_DIR"
if [ "$ipk_count" -eq 0 ]; then
  exit 2
fi

echo "Checking IPK file type:"
file "$BASE_DIR"/*.ipk || true

