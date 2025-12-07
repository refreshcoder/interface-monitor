#!/bin/sh

# Log directory
LOG_DIR="/var/log/interface_monitor"
mkdir -p "$LOG_DIR"

# Initialize state file
state_file="/tmp/interface_state"
[ ! -f "$state_file" ] && touch "$state_file"

# Function to rotate log if too big (e.g. 1MB)
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

get_interface_state() {
    local interface=$1
    local speed
    local link_status

    speed=$(ethtool "$interface" 2>/dev/null | grep -i 'Speed' | awk '{print $2}')
    link_status=$(ethtool "$interface" 2>/dev/null | grep -i 'Link detected' | awk '{print $3}')

    echo "$speed $link_status"
}

# Check interface state and log changes
check_interfaces() {
    local iface_list="$1"
    for interface in $iface_list; do
        new_state=$(get_interface_state "$interface")
        old_state=$(grep "^$interface " "$state_file" | awk '{print $2, $3}')

        # If there is no record of this interface in the state file
        if [ -z "$old_state" ]; then
            echo "$(date +"%Y-%m-%d %H:%M:%S") State initialization $interface changed from no state to $new_state" >> "$log_file"
            echo "$interface $new_state" >> "$state_file"
        # If the state has changed
        elif [ "$new_state" != "$old_state" ]; then
            echo "$(date +"%Y-%m-%d %H:%M:%S") State update $interface changed from $old_state to $new_state" >> "$log_file"
            sed -i "/^$interface /d" "$state_file"
            echo "$interface $new_state" >> "$state_file"
        fi
    done
}

# Small delay to ensure system is up
sleep 10

# Check for ethtool dependency
if ! command -v ethtool >/dev/null 2>&1; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") Error: ethtool not found. Please install ethtool." >> "$LOG_DIR/error.log"
    exit 1
fi

# Initialize log file
current_date=$(date +"%Y-%m-%d")
log_file="$LOG_DIR/$current_date.log"

# Check interface state every interval
while true; do
    new_date=$(date +"%Y-%m-%d")

    # If the date has changed, update the log file path
    if [ "$new_date" != "$current_date" ]; then
        current_date=$new_date
        log_file="$LOG_DIR/$current_date.log"
    fi
    
    check_log_rotation "$log_file"

    # Read config from UCI
    # Get all 'interfaces' values from the list
    interfaces=$(uci -q show interface_monitor.settings.interfaces | cut -d"'" -f2 | tr '\n' ' ')
    interval=$(uci -q get interface_monitor.settings.monitor_interval)
    [ -z "$interval" ] && interval=60
    
    if [ -n "$interfaces" ]; then
        check_interfaces "$interfaces"
    fi
    
    sleep "$interval"
done

