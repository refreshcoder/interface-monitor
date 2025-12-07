# Interface Monitor & Connectivity Watchdog

This repository contains OpenWrt packages for monitoring network interfaces and internet connectivity.

## Packages Included

1.  **interface-monitor**:
    *   Backend service that monitors interface link speed/status changes.
    *   Performs periodic connectivity checks (Ping) to a target IP.
    *   Logs detailed metrics (Status, Loss, RTT) to `/var/log/interface_monitor`.
    *   Supports log rotation and service reloading.

2.  **luci-app-interface-monitor**:
    *   Web UI (LuCI) for configuration.
    *   Configure monitored interfaces, target IP, and intervals.
    *   View historical logs directly in the browser.

## How to Compile (GitHub Actions)

This repository is configured with **GitHub Actions** to automatically build `.ipk` packages for common OpenWrt targets.

1.  **Fork** this repository or push it to your own GitHub account.
2.  Go to the **Actions** tab.
3.  You will see a "Build OpenWrt Packages" workflow running (on push) or you can manually trigger it.
4.  Once completed, download the **Artifacts** (zip file) for your architecture:
    *   `x86_64` (iStoreOS, Soft Routers)
    *   `ramips_mt7621` (Xiaomi AX3000, Redmi AX6000, CR660x)
    *   `rockchip_armv8` (NanoPi R2S/R4S/R5S)

## Installation

1.  Upload the `.ipk` files to your router (e.g., `/tmp/`).
2.  Install via command line:
    ```bash
    cd /tmp
    opkg update
    opkg install interface-monitor_*.ipk
    opkg install luci-app-interface-monitor_*.ipk
    ```
3.  Refresh your LuCI page, and go to **Status** -> **Interface Monitor**.

## Configuration

*   **Interfaces**: Select which physical interfaces to monitor (e.g., eth0, eth1).
*   **Connectivity Monitor**: Enable to ping a target (e.g., 8.8.8.8) and log drops/latency.
*   **Intervals**: Adjust how often to check link state and connectivity.
