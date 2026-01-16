#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

print_info "NixOS RPi5 Installer with Disko"
echo ""

# Get list of block devices (excluding loop devices, rom devices, and currently mounted root)
print_info "Scanning for available block devices..."
mapfile -t devices < <(lsblk -ndo NAME,SIZE,TYPE,MODEL | grep -E "disk" | grep -v -E "^loop|^sr" | awk '{print $1}')

if [ ${#devices[@]} -eq 0 ]; then
    print_error "No suitable block devices found!"
    exit 1
fi

# Display device information
echo ""
print_info "Available devices:"
echo ""
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MODEL,MOUNTPOINTS | grep -v -E "^loop|^sr" || true
echo ""

# Create selection menu
print_warning "SELECT THE TARGET DEVICE (ALL DATA WILL BE DESTROYED!)"
echo ""
PS3="Enter device number (or 'q' to quit): "
select device in "${devices[@]}" "Quit"; do
    if [[ "$REPLY" == "q" ]] || [[ "$REPLY" == "Q" ]]; then
        print_info "Installation cancelled."
        exit 0
    fi
    
    if [[ -n "$device" ]] && [[ "$device" != "Quit" ]]; then
        DEVICE="/dev/$device"
        break
    else
        print_error "Invalid selection. Please try again."
    fi
done

# Confirm selection
echo ""
print_warning "You selected: $DEVICE"
lsblk "$DEVICE" || true
echo ""
print_error "THIS WILL COMPLETELY ERASE ALL DATA ON $DEVICE!"
echo ""
read -p "Type 'YES' (in capital letters) to continue: " confirmation

if [[ "$confirmation" != "YES" ]]; then
    print_info "Installation cancelled."
    exit 0
fi

# Check if device is mounted and try to unmount
if mount | grep -q "$DEVICE"; then
    print_warning "Device partitions are mounted. Attempting to unmount..."
    umount -R "$DEVICE"* 2>/dev/null || true
    sleep 1
fi

# Get flake configuration name
FLAKE_CONFIG="${1:-rpi5-installer2}"
print_info "Using flake configuration: $FLAKE_CONFIG"
echo ""

# Run disko-install
print_info "Starting disko-install..."
print_warning "This will:"
print_warning "  1. Partition $DEVICE according to Disko configuration"
print_warning "  2. Format the partitions"
print_warning "  3. Install NixOS"
echo ""

# Update the device in the Disko configuration dynamically
# Note: This requires the flake configuration to accept the device as an override
print_info "Running disko-install with device override..."

# Execute disko-install
nix run 'github:nix-community/disko#disko-install' -- \
    --flake ".#$FLAKE_CONFIG" \
    --disk primary "$DEVICE"

print_success "Installation complete!"
echo ""
print_info "Next steps:"
echo "  1. Remove the SD card from this machine"
echo "  2. Insert it into your Raspberry Pi 5"
echo "  3. Power on the device"
echo "  4. Access via SSH or console"
echo ""
print_success "Done!"
