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

    # read UCI settings each loop
    enable=$(uci -q get interface_monitor.settings.connectivity_enable)
    # Handle target_ip as list or single value
    targets=$(uci -q show interface_monitor.settings.target_ip | cut -d"'" -f2)
    interval=$(uci -q get interface_monitor.settings.ping_interval)
    [ -z "$interval" ] && interval=60
    echo "$interval" | grep -Eq '^[0-9]+$' || interval=60
    [ "$interval" -lt 5 ] && interval=5
    find "$LOG_DIR" -type f -name "*.log*" -mtime +7 -delete
    verbose=$(uci -q get interface_monitor.settings.connectivity_verbose)
    [ -z "$verbose" ] && verbose=0

    if [ "$enable" = "1" ] && [ -n "$targets" ]; then
        for target_ip in $targets; do
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
                # Output format: "8.8.8.8 via 192.168.1.1 dev eth0 src 192.168.1.100 uid 0"
                # or "192.168.1.1 dev eth0 src 192.168.1.100 uid 0" (connected directly)
                # We want "eth0"
                target_iface=$(echo "$route_info" | grep -o 'dev [^ ]*' | cut -d' ' -f2)
            else
                target_iface="unknown"
            fi
            
            # Structured Log Format: Timestamp|IP|Status|Loss|RTT|Interface
            ts=$(date +"%Y-%m-%d %H:%M:%S")
            
            old_record=$(grep "^$target_ip " "$state_file")
            old_status=$(echo "$old_record" | awk '{print $2}')
            
            if [ -z "$old_status" ]; then
                echo "$ts|$target_ip|$status|$loss_str|$rtt_avg|$target_iface" >> "$log_file"
                echo "$target_ip $status" >> "$state_file"
            elif [ "$status" != "$old_status" ]; then
                echo "$ts|$target_ip|$status|$loss_str|$rtt_avg|$target_iface" >> "$log_file"
                sed -i "/^$target_ip /d" "$state_file"
                echo "$target_ip $status" >> "$state_file"
            elif [ "$verbose" = "1" ]; then
                echo "$ts|$target_ip|$status|$loss_str|$rtt_avg|$target_iface" >> "$log_file"
            fi
        done
    fi

    sleep "$interval"
done
