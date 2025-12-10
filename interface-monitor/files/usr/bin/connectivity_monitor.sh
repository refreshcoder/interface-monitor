#!/bin/sh

LOG_DIR="/tmp/log/interface_monitor"
mkdir -p "$LOG_DIR"
ERR_LOG="$LOG_DIR/error.log"

state_file="/tmp/connectivity_state"
[ ! -f "$state_file" ] && touch "$state_file"

# Delay start
sleep 10

current_date=$(date +"%Y-%m-%d")
metrics_log_file="$LOG_DIR/conn_metrics_$current_date.log"
events_log_file="$LOG_DIR/conn_events_$current_date.log"

check_log_rotation() {
    local file="$1"
    local max_size=1048576 # 1MB
    if [ -f "$file" ]; then
        local size=$(ls -l "$file" | awk '{print $5}')
        if [ -n "$size" ] && [ "$size" -gt "$max_size" ]; then
            mv "$file" "$file.old"
        fi
    fi
}

while true; do
    # rotate daily log file
    new_date=$(date +"%Y-%m-%d")
    if [ "$new_date" != "$current_date" ]; then
        current_date=$new_date
        metrics_log_file="$LOG_DIR/conn_metrics_$current_date.log"
        events_log_file="$LOG_DIR/conn_events_$current_date.log"
    fi
    
    check_log_rotation "$metrics_log_file"
    check_log_rotation "$events_log_file"

    enable=$(uci -q get interface_monitor.settings.connectivity_enable)
    log_format=$(uci -q get interface_monitor.settings.log_format)
    [ -z "$log_format" ] && log_format="jsonl"
    active_probe=$(uci -q get interface_monitor.settings.active_probe_enable)
    [ -z "$active_probe" ] && active_probe=1
    probe_method=$(uci -q get interface_monitor.settings.probe_method)
    [ -z "$probe_method" ] && probe_method="ping"
    rtt_warn=$(uci -q get interface_monitor.settings.rtt_warn_ms)
    [ -z "$rtt_warn" ] && rtt_warn=50
    rtt_bad=$(uci -q get interface_monitor.settings.rtt_bad_ms)
    [ -z "$rtt_bad" ] && rtt_bad=200
    loss_warn=$(uci -q get interface_monitor.settings.loss_warn_pct)
    [ -z "$loss_warn" ] && loss_warn=5
    loss_bad=$(uci -q get interface_monitor.settings.loss_bad_pct)
    [ -z "$loss_bad" ] && loss_bad=20
    # Prefer full list from `uci show`, extract all quoted values
    line=$(uci -q show interface_monitor.settings | grep "^interface_monitor.settings.target_ip=")
    targets=$(echo "$line" | grep -o "'[^']*'" | tr -d "'" | tr '\n' ' ' | tr -s ' ')
    line_passive=$(uci -q show interface_monitor.settings | grep "^interface_monitor.settings.passive_device=")
    passive_list=$(echo "$line_passive" | grep -o "'[^']*'" | tr -d "'" | tr '\n' ' ' | tr -s ' ')
    # Fallback to single-value option if list not present
    [ -z "$targets" ] && targets=$(uci -q get interface_monitor.settings.target_ip 2>/dev/null)
    interval=$(uci -q get interface_monitor.settings.ping_interval)
    [ -z "$interval" ] && interval=60
    echo "$interval" | grep -Eq '^[0-9]+$' || interval=60
    [ "$interval" -lt 5 ] && interval=5
    find "$LOG_DIR" -type f -name "*.log*" -mtime +7 -delete
    verbose=$(uci -q get interface_monitor.settings.connectivity_verbose)
    [ -z "$verbose" ] && verbose=0

    if [ "$enable" = "1" ] && [ -n "$targets" ]; then
        for target_ip in $targets; do
            # Skip empty entries
            [ -z "$target_ip" ] && continue

            should_probe=$active_probe
            for p in $passive_list; do
                [ "$p" = "$target_ip" ] && should_probe=0
            done

            if [ "$should_probe" = "1" ]; then
                ping_out=$(ping -c 3 -W 2 "$target_ip" 2>&1)
                if [ $? -eq 0 ]; then
                    status="up"
                    loss_str=$(echo "$ping_out" | grep "packet loss" | sed 's/.*, \([0-9]*\)% packet loss.*/\1/')
                    rtt_line=$(echo "$ping_out" | grep -E "round-trip|rtt")
                    if echo "$rtt_line" | grep -q "round-trip"; then
                        rtt_avg=$(echo "$rtt_line" | awk -F'/' '{print $4}')
                    else
                        rtt_avg=$(echo "$rtt_line" | awk -F'/' '{print $5}')
                    fi
                    [ -z "$rtt_avg" ] && rtt_avg="0"
                    [ -z "$loss_str" ] && loss_str="0"
                    probe_used="ping"
                else
                    status="down"
                    loss_str="100"
                    rtt_avg="0"
                    probe_used="ping"
                fi
            else
                neigh_line=$(ip neigh show "$target_ip")
                if [ -n "$neigh_line" ] && ! echo "$neigh_line" | grep -q "FAILED"; then
                    status="up"
                else
                    status="down"
                fi
                loss_str="0"
                rtt_avg="0"
                probe_used="passive"
            fi
            
            # Get outgoing interface for this target
            route_info=$(ip route get "$target_ip" 2>/dev/null)
            if [ -n "$route_info" ]; then
                target_iface=$(echo "$route_info" | grep -o 'dev [^ ]*' | cut -d' ' -f2)
            else
                target_iface="unknown"
            fi
            
            # --- Extended Info Detection ---
            mac="unknown"
            hostname="unknown"
            phy_iface="$target_iface"

            # 1. MAC Address
            neigh=$(ip neigh show "$target_ip")
            if [ -n "$neigh" ]; then
                mac=$(echo "$neigh" | awk '{print $5}')
            fi
            if [ -z "$mac" ] || [ "$mac" = "unknown" ]; then
                mac=$(arp -n "$target_ip" 2>/dev/null | grep -v "incomplete" | awk '{print $3}')
            fi
            [ -z "$mac" ] && mac="unknown"

            # 2. Hostname from dhcp.leases
            if [ "$mac" != "unknown" ]; then
                dhcp_name=$(grep -i "$mac" /tmp/dhcp.leases 2>/dev/null | awk '{print $4}')
                [ -n "$dhcp_name" ] && hostname="$dhcp_name"
            fi
            
            # 3. Physical Interface (if bridge)
            if echo "$target_iface" | grep -q "^br-" && [ "$mac" != "unknown" ]; then
                # Try bridge fdb
                fdb_out=$(bridge fdb show 2>/dev/null | grep -i "$mac")
                if [ -n "$fdb_out" ]; then
                     p_if=$(echo "$fdb_out" | grep "dev" | sed 's/.*dev \([^ ]*\).*/\1/' | grep -v "^$target_iface" | head -n 1)
                     [ -n "$p_if" ] && phy_iface="$p_if"
                else
                    # Fallback to brctl showmacs
                    port_no=$(brctl showmacs "$target_iface" 2>/dev/null | grep -i "$mac" | awk '{print $1}')
                    if [ -n "$port_no" ] && [ -d "/sys/class/net/$target_iface/brif" ]; then
                         for brif in "/sys/class/net/$target_iface/brif/"*; do
                             if [ -f "$brif/port_no" ]; then
                                 p=$(cat "$brif/port_no")
                                 p_dec=$((p))
                                 if [ "$p_dec" -eq "$port_no" ]; then
                                     phy_iface=$(basename "$brif")
                                     break
                                 fi
                             fi
                         done
                    fi
                fi
            fi
            
            ts=$(date +"%Y-%m-%dT%H:%M:%S%z")

            status_eval="$status"
            if [ "$status" = "up" ]; then
                is_bad=$(awk -v r="$rtt_avg" -v lb="$loss_bad" -v l="$loss_str" -v rb="$rtt_bad" 'BEGIN{if ((l+0)>= (lb+0) || (r+0)>= (rb+0)) print 1; else print 0}')
                is_warn=$(awk -v r="$rtt_avg" -v lw="$loss_warn" -v l="$loss_str" -v rw="$rtt_warn" 'BEGIN{if ((l+0)>= (lw+0) || (r+0)>= (rw+0)) print 1; else print 0}')
                if [ "$is_bad" = "1" ] || [ "$is_warn" = "1" ]; then
                    status_eval="degraded"
                fi
            fi
            status="$status_eval"

            if [ "$log_format" = "jsonl" ]; then
                echo "{\"ts\":\"$ts\",\"schema_version\":1,\"source\":\"connectivity\",\"ip\":\"$target_ip\",\"mac\":\"$mac\",\"hostname\":\"$hostname\",\"iface\":\"$target_iface\",\"phy_iface\":\"$phy_iface\",\"status\":\"$status\",\"probe_method\":\"$probe_used\",\"samples\":3,\"rtt_ms_avg\":$rtt_avg,\"loss_pct\":$loss_str,\"thresholds\":{\"rtt_warn_ms\":$rtt_warn,\"rtt_bad_ms\":$rtt_bad,\"loss_warn_pct\":$loss_warn,\"loss_bad_pct\":$loss_bad}}" >> "$metrics_log_file"
            else
                echo "ts=$ts|source=connectivity|schema_version=1|ip=$target_ip|mac=$mac|hostname=$hostname|iface=$target_iface|phy_iface=$phy_iface|status=$status|probe_method=$probe_used|samples=3|rtt_ms_avg=$rtt_avg|loss_pct=$loss_str|thresholds.rtt_warn_ms=$rtt_warn|thresholds.rtt_bad_ms=$rtt_bad|thresholds.loss_warn_pct=$loss_warn|thresholds.loss_bad_pct=$loss_bad" >> "$metrics_log_file"
            fi
            
            # Update state file
            old_record=$(grep "^$target_ip " "$state_file")
            old_status=$(echo "$old_record" | awk '{print $2}')
            
            if [ -z "$old_status" ]; then
                echo "$target_ip $status" >> "$state_file"
                if [ "$log_format" = "jsonl" ]; then
                    echo "{\"ts\":\"$ts\",\"schema_version\":1,\"source\":\"connectivity\",\"ip\":\"$target_ip\",\"event\":\"state_change\",\"old_status\":\"none\",\"new_status\":\"$status\",\"reason\":\"probe_result\",\"metrics\":{\"rtt_ms_avg\":$rtt_avg,\"loss_pct\":$loss_str},\"iface\":\"$target_iface\",\"phy_iface\":\"$phy_iface\"}" >> "$events_log_file"
                else
                    echo "ts=$ts|source=connectivity|schema_version=1|ip=$target_ip|event=state_change|old_status=none|new_status=$status|reason=probe_result|metrics.rtt_ms_avg=$rtt_avg|metrics.loss_pct=$loss_str|iface=$target_iface|phy_iface=$phy_iface" >> "$events_log_file"
                fi
            elif [ "$status" != "$old_status" ]; then
                sed -i "/^$target_ip /d" "$state_file"
                echo "$target_ip $status" >> "$state_file"
                ev="state_change"
                if [ "$status" = "degraded" ] && [ "$old_status" = "up" ]; then
                    ev="degraded"
                elif [ "$status" = "up" ] && [ "$old_status" = "degraded" ]; then
                    ev="recovered"
                fi
                if [ "$log_format" = "jsonl" ]; then
                    echo "{\"ts\":\"$ts\",\"schema_version\":1,\"source\":\"connectivity\",\"ip\":\"$target_ip\",\"event\":\"$ev\",\"old_status\":\"$old_status\",\"new_status\":\"$status\",\"reason\":\"probe_result\",\"metrics\":{\"rtt_ms_avg\":$rtt_avg,\"loss_pct\":$loss_str},\"iface\":\"$target_iface\",\"phy_iface\":\"$phy_iface\"}" >> "$events_log_file"
                else
                    echo "ts=$ts|source=connectivity|schema_version=1|ip=$target_ip|event=$ev|old_status=$old_status|new_status=$status|reason=probe_result|metrics.rtt_ms_avg=$rtt_avg|metrics.loss_pct=$loss_str|iface=$target_iface|phy_iface=$phy_iface" >> "$events_log_file"
                fi
            fi
        done
    else
        ts=$(date +"%Y-%m-%dT%H:%M:%S%z")
        if [ "$enable" != "1" ]; then
            echo "$ts|warn|connectivity disabled" >> "$ERR_LOG"
        elif [ -z "$targets" ]; then
            echo "$ts|warn|no target_ip configured" >> "$ERR_LOG"
        fi
    fi
    
    sleep "$interval"
done
