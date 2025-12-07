#!/bin/sh

LOG_DIR="/var/log/interface_monitor"
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

    # read UCI settings each loop so changes take effect without restart
    enable=$(uci -q get interface_monitor.settings.connectivity_enable)
    target_ip=$(uci -q get interface_monitor.settings.target_ip)
    interval=$(uci -q get interface_monitor.settings.ping_interval)
    [ -z "$interval" ] && interval=60

    if [ "$enable" = "1" ] && [ -n "$target_ip" ]; then
        # Ping 3 times to get stats
        ping_out=$(ping -c 3 -W 2 "$target_ip" 2>&1)
        if [ $? -eq 0 ]; then
            status="up"
            # Extract loss (e.g., "0% packet loss")
            loss_str=$(echo "$ping_out" | grep "packet loss" | sed 's/.*, \([0-9]*\)% packet loss.*/\1/')
            
            # Extract avg RTT (round-trip min/avg/max = ...)
            # Busybox ping output format varies:
            # "round-trip min/avg/max = ..." or "rtt min/avg/max/mdev = ..."
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
        
        curr_details="loss:${loss_str}% rtt:${rtt_avg}ms"
        
        old_record=$(grep "^$target_ip " "$state_file")
        old_status=$(echo "$old_record" | awk '{print $2}')
        
        if [ -z "$old_status" ]; then
            echo "$(date +"%Y-%m-%d %H:%M:%S") Connectivity init $target_ip: $status ($curr_details)" >> "$log_file"
            echo "$target_ip $status" >> "$state_file"
        elif [ "$status" != "$old_status" ]; then
            echo "$(date +"%Y-%m-%d %H:%M:%S") Connectivity update $target_ip changed from $old_status to $status ($curr_details)" >> "$log_file"
            sed -i "/^$target_ip /d" "$state_file"
            echo "$target_ip $status" >> "$state_file"
        fi
    fi

    sleep "$interval"
done


