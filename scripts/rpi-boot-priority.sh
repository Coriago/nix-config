#!/usr/bin/env bash
set -euo pipefail

PI_HOST="${1:-}"

if [[ -z "$PI_HOST" ]]; then
    echo "Usage: $0 <pi-hostname-or-ip>"
    exit 1
fi

# Boot order codes for Raspberry Pi
# 0x1 = SD card, 0x4 = USB, 0x6 = NVMe
declare -A BOOT_NAMES=(
    ["0x1"]="SD Card"
    ["0x4"]="USB"
    ["0x6"]="NVMe"
)

echo "Connecting to $PI_HOST..."
CURRENT=$(ssh "$PI_HOST" "sudo rpi-eeprom-config | grep BOOT_ORDER" | cut -d= -f2)
echo "Current boot order: $CURRENT"

echo ""
echo "Select new boot priority:"
echo "  1) SD Card first"
echo "  2) USB first"
echo "  3) NVMe first"
read -p "Choice [1-3]: " choice

case "$choice" in
    1) NEW_ORDER="0xf41" ;;  # SD -> USB -> NVMe -> restart
    2) NEW_ORDER="0xf14" ;;  # USB -> SD -> NVMe -> restart
    3) NEW_ORDER="0xf416" ;; # NVMe -> USB -> SD -> restart
    *) echo "Invalid choice"; exit 1 ;;
esac

echo "Setting boot order to $NEW_ORDER..."
ssh "$PI_HOST" "sudo rpi-eeprom-config --out /tmp/boot.conf && \
    sudo sed -i 's/^BOOT_ORDER=.*/BOOT_ORDER=$NEW_ORDER/' /tmp/boot.conf && \
    sudo rpi-eeprom-config --apply /tmp/boot.conf && \
    sudo rm /tmp/boot.conf"

read -p "Reboot now? [y/N]: " reboot
if [[ "$reboot" =~ ^[Yy]$ ]]; then
    echo "Rebooting..."
    ssh "$PI_HOST" "sudo reboot" || true
fi
