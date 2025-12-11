#!/bin/sh

# Log directory
LOG_DIR="/tmp/log/interface_monitor"
mkdir -p "$LOG_DIR"

# Initialize state file
state_file="/tmp/interface_state"
[ ! -f "$state_file" ] && touch "$state_file"

# Function to rotate log if too big (e.g. 1MB)
check_log_rotation() {
    local file="$1"
    local max_size=1048576
    if [ -f "$file" ]; then
        local size=$(ls -l "$file" | awk '{print $5}')
        if [ -n "$size" ] && [ "$size" -gt "$max_size" ]; then
            mv "$file" "$file.old"
        fi
    fi
}

get_interface_state() {
    local interface=$1
    local speed
    local link_status
    local duplex
    speed=$(ethtool "$interface" 2>/dev/null | grep -i 'Speed' | awk '{print $2}')
    link_status=$(ethtool "$interface" 2>/dev/null | grep -i 'Link detected' | awk '{print $3}')
    duplex=$(ethtool "$interface" 2>/dev/null | grep -i 'Duplex' | awk '{print $2}')
    echo "$speed $link_status $duplex"
}

# Check interface state and log changes
check_interfaces() {
    local iface_list="$1"
    for interface in $iface_list; do
        new_state=$(get_interface_state "$interface")
        old_state=$(grep "^$interface " "$state_file" | awk '{print $2, $3, $4}')
        ts=$(date +"%Y-%m-%dT%H:%M:%S%z")
        speed=$(echo "$new_state" | awk '{print $1}')
        link_status=$(echo "$new_state" | awk '{print $2}')
        duplex=$(echo "$new_state" | awk '{print $3}')
        if [ -z "$old_state" ]; then
            echo "$interface $new_state" >> "$state_file"
            if [ "$log_format" = "jsonl" ]; then
                echo "{\"ts\":\"$ts\",\"schema_version\":1,\"source\":\"iface\",\"interface\":\"$interface\",\"event\":\"init\",\"old\":{\"speed\":\"none\",\"link\":\"none\",\"duplex\":\"none\"},\"new\":{\"speed\":\"$speed\",\"link\":\"$link_status\",\"duplex\":\"$duplex\"}}" >> "$log_file"
            else
                echo "ts=$ts|source=iface|schema_version=1|interface=$interface|event=init|old.speed=none|old.link=none|old.duplex=none|new.speed=$speed|new.link=$link_status|new.duplex=$duplex" >> "$log_file"
            fi
        elif [ "$new_state" != "$old_state" ]; then
            old_speed=$(echo "$old_state" | awk '{print $1}')
            old_link=$(echo "$old_state" | awk '{print $2}')
            old_duplex=$(echo "$old_state" | awk '{print $3}')
            sed -i "/^$interface /d" "$state_file"
            echo "$interface $new_state" >> "$state_file"
            ev="update"
            if [ "$old_link" != "$link_status" ]; then
                if [ "$link_status" = "yes" ]; then
                    ev="link_up"
                else
                    ev="link_down"
                fi
            elif [ "$old_speed" != "$speed" ]; then
                ev="speed_change"
            elif [ "$old_duplex" != "$duplex" ]; then
                ev="duplex_change"
            fi
            if [ "$log_format" = "jsonl" ]; then
                echo "{\"ts\":\"$ts\",\"schema_version\":1,\"source\":\"iface\",\"interface\":\"$interface\",\"event\":\"$ev\",\"old\":{\"speed\":\"$old_speed\",\"link\":\"$old_link\",\"duplex\":\"$old_duplex\"},\"new\":{\"speed\":\"$speed\",\"link\":\"$link_status\",\"duplex\":\"$duplex\"}}" >> "$log_file"
            else
                echo "ts=$ts|source=iface|schema_version=1|interface=$interface|event=$ev|old.speed=$old_speed|old.link=$old_link|old.duplex=$old_duplex|new.speed=$speed|new.link=$link_status|new.duplex=$duplex" >> "$events_log_file"
            fi
        fi
        if [ "$log_format" = "jsonl" ]; then
            echo "{\"ts\":\"$ts\",\"schema_version\":1,\"source\":\"iface\",\"interface\":\"$interface\",\"link\":\"$link_status\",\"speed\":\"$speed\",\"duplex\":\"$duplex\"}" >> "$log_file"
        else
            echo "ts=$ts|source=iface|schema_version=1|interface=$interface|link=$link_status|speed=$speed|duplex=$duplex" >> "$log_file"
        fi
    done
}

# Small delay to ensure system is up
sleep 10

# Check for ethtool dependency
if ! command -v ethtool >/dev/null 2>&1; then
    echo "$(date +"%Y-%m-%dT%H:%M:%S%z")|error|ethtool not found" >> "$LOG_DIR/error.log"
    exit 1
fi

log_file="$LOG_DIR/iface.log"

# Check interface state every interval
while true; do
    new_date=$(date +"%Y-%m-%d")

    # If the date has changed, update the log file path
check_log_rotation "$log_file"

    # Read config from UCI
    # Extract all quoted values from interfaces list
    log_format=$(uci -q get interface_monitor.settings.log_format)
    [ -z "$log_format" ] && log_format="jsonl"
    line=$(uci -q show interface_monitor.settings | grep "^interface_monitor.settings.interfaces=")
    interfaces=$(echo "$line" | grep -o "'[^']*'" | tr -d "'" | tr '\n' ' ' | tr -s ' ')
    interval=$(uci -q get interface_monitor.settings.monitor_interval)
    [ -z "$interval" ] && interval=60
    echo "$interval" | grep -Eq '^[0-9]+$' || interval=60
    [ "$interval" -lt 5 ] && interval=5
    find "$LOG_DIR" -type f -name "*.log*" -mtime +7 -delete
    
    if [ -n "$interfaces" ]; then
        check_interfaces "$interfaces"
    fi
    
    sleep "$interval"
done
