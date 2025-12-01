{pkgs, ...}: let
  switch-input = pkgs.writeShellScriptBin "switch-input" ''
    #!/usr/bin/env bash
    set -euo pipefail

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
      local current_input
      current_input=$(ddcutil $ddcutil_flags getvcp -t 60 | grep -oP 'x[0-9a-f]+' | head -1)

      # Toggle the input to the other value
      local new_value
      if [[ "$current_input" == "$input1" ]]; then
        new_value="$input2"
      else
        new_value="$input1"
      fi

      ddcutil $ddcutil_flags setvcp 60 "$new_value"
    }

    read_monitor_input() {
      local bus="$1"

      # Performance flags: reduce sleep times and enable dynamic sleep adjustment
      local ddcutil_flags="--bus=$bus --sleep-multiplier=0.2 --enable-dynamic-sleep"

      ddcutil $ddcutil_flags getvcp -t 60 | grep -oP 'x[0-9a-f]+' | head -1
    }

    # Function to set monitor input to a specific value
    set_monitor_input() {
      local bus="$1"
      local input_val="$2"

      # Performance flags: reduce sleep times and enable dynamic sleep adjustment
      local ddcutil_flags="--bus=$bus --sleep-multiplier=0.2 --enable-dynamic-sleep"

      ddcutil $ddcutil_flags setvcp 60 "$input_val"
    }

    device="desktop"

    # Monitor configurations
    dell_model='DELL P2219H'
    dell_hdmi_1=x11
    dell_displayport_1=x0f
    dell_desktop_input=$dell_hdmi_1
    dell_laptop_input=$dell_displayport_1

    aoc_model='Q27G4ZD'
    aoc_displayport_1=x0f
    aoc_hdmi_1=x11
    aoc_hdmi_2=x12
    aoc_desktop_input=$aoc_displayport_1
    aoc_laptop_input=$aoc_hdmi_2

    start_time=$(date +%s.%N)

    # Run detect once to get all bus IDs
    detect_flags="--ignore-mmid=SNY-SONY_TV___00-31748 --sleep-multiplier=0.2"
    detect_output=$(ddcutil $detect_flags detect 2>/dev/null)

    # Extract bus IDs for all monitors
    dell_bus=$(get_bus_id "$dell_model" "$detect_output")
    aoc_bus=$(get_bus_id "$aoc_model" "$detect_output")

    # Get current input of primary monitor
    primary_input=$(read_monitor_input "$aoc_bus")

    # Toggle based on current value
    if [ "$primary_input" = "$aoc_desktop_input" ]; then
      device="laptop"
    else
      device="desktop"
    fi

    # Toggle inputs for both monitors
    if [ "$device" = "desktop" ]; then
      set_monitor_input "$dell_bus" "$dell_desktop_input"
      set_monitor_input "$aoc_bus" "$aoc_desktop_input"
    elif [ "$device" = "laptop" ]; then
      set_monitor_input "$dell_bus" "$dell_laptop_input"
      set_monitor_input "$aoc_bus" "$aoc_laptop_input"
    fi

    total_time=$(awk "BEGIN {printf \"%.3f\", $(date +%s.%N) - $start_time}")
    echo "Total time: ''${total_time}s"
  '';
in {
  home.packages = [
    switch-input
    pkgs.ddcutil
  ];
}
