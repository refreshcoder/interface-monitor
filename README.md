# Interface Monitor & Connectivity Watchdog

OpenWrt packages to monitor interface link state and target connectivity, with LuCI visualization and an online package feed.

## Packages

- `interface-monitor`
  - Monitors link speed/status changes and pings a target IP.
  - Writes logs to `/tmp/log/interface_monitor` (cleared on reboot).
  - Log rotation, minimal resource use, safe defaults.

- `luci-app-interface-monitor`
  - LuCI pages: Settings, Logs, Connectivity Graph, Interface Graph.
  - Heartbeat logging option for target IP to show continuous charts.

## Online Feed

- Feed layout (per OpenWrt 24.10):
  - `https://refreshcoder.github.io/interface-monitor/openwrt-24.10/x86_64/interface-monitor/`
  - Contains `*.ipk`, `Packages`, `Packages.gz`, optionally `Packages.sig`
  - Public key (if signing enabled): `https://refreshcoder.github.io/interface-monitor/openwrt-24.10/keys/opkg_pub.key`

### One‑line setup

```sh
wget -O - https://github.com/refreshcoder/interface-monitor/raw/refs/heads/main/feed.sh | ash
```

### Manual setup

```sh
echo 'src/gz interface-monitor https://refreshcoder.github.io/interface-monitor/openwrt-24.10/x86_64/interface-monitor' >> /etc/opkg/customfeeds.conf
opkg update
opkg install interface-monitor luci-app-interface-monitor
```

### Signed feeds

- Feeds use `usign`/Ed25519 keys (not RSA PEM). Generate keys:
  - `usign -G -s opkg_feed_priv -p opkg_feed_pub`
- Place public key on device:
  - `usign -F -p opkg_feed_pub` shows fingerprint; copy `opkg_feed_pub` to `/etc/opkg/keys/<fingerprint>`
- CI will generate `Packages.sig` when repository secrets are set:
  - `OPKG_SIGNING_PRIV`: private key content
  - `OPKG_SIGNING_PUB`: public key content

## Build (GitHub Actions)

- Workflow builds `x86_64` by default and publishes a Pages feed.
- Caching of downloads, parallel builds, safe artifact collection.
- Artifacts also uploaded for manual download.

## LuCI Pages

- `Status → Interface Monitor → Settings`
  - Enable Service, Monitored Interfaces, Interface Check Interval (s)
  - Enable Connectivity Monitor, Target IP, Ping Interval (s)
  - Log Heartbeat Every Interval (target IP only)

- `Status → Interface Monitor → Logs`
  - Select and view log files from `/tmp/log/interface_monitor`

- `Status → Interface Monitor → Connectivity Graph`
  - RTT(ms) and Loss(%) dual line chart
  - Range selector: 1h/6h/24h/All

- `Status → Interface Monitor → Interface Graph`
  - Negotiated speed line chart with down event markers
  - Select log file, interface name, range

## Configuration Options

- `/etc/config/interface_monitor`
  - `enabled`: `1/0` to start/stop service
  - `interfaces`: list of interface names (e.g., `eth0`)
  - `monitor_interval`: poll interval (s), min 5
  - `connectivity_enable`: `1/0` for target ping
  - `target_ip`: IPv4 address to ping
  - `ping_interval`: interval (s), min 5
  - `connectivity_verbose`: `1/0` heartbeat log each interval

## Troubleshooting

- Logs not visible
  - Ensure interfaces exist and are added in Settings
  - Check `/tmp/log/interface_monitor/` and file timestamps

- Feed 404 or signature errors
  - Wait for Pages deployment to finish; check Actions logs
  - Verify feed URL points to directory (not file)
  - If signed, install public key to `/etc/opkg/keys/<fingerprint>`

## Service Control

```sh
/etc/init.d/interface_monitor enable
/etc/init.d/interface_monitor start
/etc/init.d/interface_monitor reload
/etc/init.d/interface_monitor stop
```
