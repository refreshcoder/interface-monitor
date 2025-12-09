#!/bin/sh

LOG_DIR="/tmp/log/interface_monitor"
mkdir -p "$LOG_DIR"

state_file="/tmp/connectivity_state"
[ ! -f "$state_file" ] && touch "$state_file"

# Delay start
sleep 10

current_date=$(date +"%Y-%m-%d")
log_file="$LOG_DIR/conn_$current_date.log"

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
        log_file="$LOG_DIR/conn_$current_date.log"
    fi
    
    check_log_rotation "$log_file"

    enable=$(uci -q get interface_monitor.settings.connectivity_enable)
    targets=$(uci -q show interface_monitor.settings | sed -n "s/^interface_monitor.settings.target_ip='\([^']*\)'$/\1/p" | tr '\n' ' ' | tr -s ' ')
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

            # Ping 3 times to get stats
            ping_out=$(ping -c 3 -W 2 "$target_ip" 2>&1)
            if [ $? -eq 0 ]; then
                status="up"
                # Extract loss (e.g., "0% packet loss")
                loss_str=$(echo "$ping_out" | grep "packet loss" | sed 's/.*, \([0-9]*\)% packet loss.*/\1/')
                
                # Extract avg RTT
                rtt_line=$(echo "$ping_out" | grep -E "round-trip|rtt")
                if echo "$rtt_line" | grep -q "round-trip"; then
                    rtt_avg=$(echo "$rtt_line" | awk -F'/' '{print $4}')
                else
                    rtt_avg=$(echo "$rtt_line" | awk -F'/' '{print $5}')
                fi
                
                # Fallback if empty
                [ -z "$rtt_avg" ] && rtt_avg="0"
                [ -z "$loss_str" ] && loss_str="0"
            else
                status="down"
                loss_str="100"
                rtt_avg="0"
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
            
            # Structured Log Format: Timestamp|IP|Status|Loss|RTT|Interface|MAC|Hostname|PhyInterface
            # Log every check to ensure continuous graph data
            ts=$(date +"%Y-%m-%d %H:%M:%S")
            echo "$ts|$target_ip|$status|$loss_str|$rtt_avg|$target_iface|$mac|$hostname|$phy_iface" >> "$log_file"
            
            # Update state file
            old_record=$(grep "^$target_ip " "$state_file")
            old_status=$(echo "$old_record" | awk '{print $2}')
            
            if [ -z "$old_status" ]; then
                echo "$target_ip $status" >> "$state_file"
            elif [ "$status" != "$old_status" ]; then
                sed -i "/^$target_ip /d" "$state_file"
                echo "$target_ip $status" >> "$state_file"
            fi
        done
    fi
    
    sleep "$interval"
done
