#!/usr/bin/env bash

# Function to get bus ID for a monitor from detect output
get_bus_id() {
  local monitor_model="$1"
  local detect_output="$2"
  echo "$detect_output" | grep -B 10 "$monitor_model" | grep "I2C bus:" | grep -oP 'i2c-\K[0-9]+'
}

# Function to toggle monitor input between two values
toggle_monitor_input() {
  local bus="$1"
  local input1="$2"
  local input2="$3"
  
  # Performance flags: reduce sleep times and enable dynamic sleep adjustment
  local ddcutil_flags="--bus=$bus --sleep-multiplier=0.2 --enable-dynamic-sleep"
  
  # Get the current value and extract just the code (e.g., "x11" from "VCP 60 SNC x11")
  local current_input=$(ddcutil $ddcutil_flags getvcp -t 60 | grep -oP 'x[0-9a-f]+' | head -1)
  
  # Toggle the input to the other value
  local new_value=$([[ "$current_input" == "$input1" ]] && echo "$input2" || echo "$input1")
  ddcutil $ddcutil_flags setvcp 60 "$new_value"
}

read_monitor_input() {
  local bus="$1"
  
  # Performance flags: reduce sleep times and enable dynamic sleep adjustment
  local ddcutil_flags="--bus=$bus --sleep-multiplier=0.2 --enable-dynamic-sleep"
  
  echo $(ddcutil $ddcutil_flags getvcp -t 60 | grep -oP 'x[0-9a-f]+' | head -1)
}

# Function to toggle monitor input between two values
set_monitor_input() {
  local bus="$1"
  local input_val="$2"
  
  # Performance flags: reduce sleep times and enable dynamic sleep adjustment
  local ddcutil_flags="--bus=$bus --sleep-multiplier=0.2 --enable-dynamic-sleep"
  
  ddcutil $ddcutil_flags setvcp 60 "$input_val"
}

device="desktop"

# Monitor configurations
monitor_1_model='Q27G3XMN'
monitor_1_displayport_1=x0f
monitor_1_hdmi_1=x11
monitor_1_hdmi_2=x12
monitor_1_desktop_input=$monitor_1_displayport_1
monitor_1_laptop_input=$monitor_1_hdmi_2

monitor_2_model='Q27G4ZD'
monitor_2_displayport_1=x0f
monitor_2_hdmi_1=x11
monitor_2_hdmi_2=x12
monitor_2_desktop_input=$monitor_2_displayport_1
monitor_2_laptop_input=$monitor_2_hdmi_2
start_time=$(date +%s.%N)

# Run detect once to get all bus IDs
detect_flags="--ignore-mmid=SNY-SONY_TV___00-31748 --sleep-multiplier=0.2"
detect_output=$(ddcutil $detect_flags detect 2>/dev/null)

# Extract bus IDs for all monitors
monitor_1_bus=$(get_bus_id "$monitor_1_model" "$detect_output")
monitor_2_bus=$(get_bus_id "$monitor_2_model" "$detect_output")

# Get current input of primary monitor
primary_input=$(read_monitor_input "$monitor_1_bus")
# Toggle based on current value
if [ "$primary_input" = "$monitor_1_desktop_input" ]; then
  device="laptop"
else
  device="desktop"
fi

echo "monitor_1_bus: $monitor_1_bus"
echo "monitor_2_bus: $monitor_2_bus"

# Toggle inputs for both monitors
if [ "$device" = "desktop" ]; then
  set_monitor_input "$monitor_1_bus" "$monitor_1_desktop_input" &
  set_monitor_input "$monitor_2_bus" "$monitor_2_desktop_input" &
elif [ "$device" = "laptop" ]; then
  set_monitor_input "$monitor_1_bus" "$monitor_1_laptop_input" &
  set_monitor_input "$monitor_2_bus" "$monitor_2_laptop_input" &
fi

total_time=$(awk "BEGIN {printf \"%.3f\", $(date +%s.%N) - $start_time}")
echo "Total time: ${total_time}s"