#!/bin/bash
set -e

# Check if this is a reMarkable Paper Pro (has lpgpr root_part file)
if [[ -f /sys/devices/platform/lpgpr/root_part ]]; then
    # Paper Pro: determine current partition from mount point
    running_dev=$(mount | grep ' / ' | cut -d' ' -f1)
    base_dev=${running_dev%p*}
    running_p=${running_dev##*p}
    other_p=$(( running_p == 2 ? 3 : 2 ))
    
    # Get next boot partition from root_part (a/b format)
    next_boot_part=$(cat /sys/devices/platform/lpgpr/root_part)
    if [[ "$next_boot_part" == "a" ]]; then
        boot_p=2
    elif [[ "$next_boot_part" == "b" ]]; then
        boot_p=3
    else
        boot_p="$running_p"  # fallback to current
    fi
else
    # Original reMarkable: use rootdev
    # 1. Determine the running device+partition (e.g. /dev/mmcblk2p2)
    running_dev=$(rootdev)
    running_p=${running_dev##*p}    # "2"

    # 2. Derive the block-device base (everything before the "p2")
    base_dev=${running_dev%p*}          # e.g. /dev/mmcblk2

    # 3. Figure out the other (fallback) partition
    other_p=$(( running_p == 2 ? 3 : 2 ))
    
    # 4. Get next boot partition from U-Boot env
    boot_p=$(fw_printenv active_partition 2>/dev/null | cut -d= -f2)
    # If fw_printenv fails or returns empty, assume next boot is current partition
    if [[ -z "$boot_p" || "$boot_p" == "unknown" ]]; then
        boot_p="$running_p"
    fi
fi

# 5. Read & clean version on the active root
active_version=$(grep '^IMG_VERSION=' /etc/os-release \
                 | cut -d= -f2 | tr -d '"')

# 6. Mount & clean version on the fallback root
mnt=$(mktemp -d)
mount -o ro "${base_dev}p${other_p}" "$mnt"

# Set up cleanup trap to ensure umount/rmdir always run
cleanup() {
  umount "$mnt" 2>/dev/null || true
  rmdir "$mnt" 2>/dev/null || true
}
trap cleanup EXIT

fallback_version=$(grep '^IMG_VERSION=' "$mnt/etc/os-release" \
                   | cut -d= -f2 | tr -d '"')

# 7. Determine version for next boot partition
if [[ "$boot_p" == "$running_p" ]]; then
  boot_version=$active_version
elif [[ "$boot_p" == "$other_p" ]]; then
  boot_version=$fallback_version
else
  boot_version="unknown"
fi

# 8. Print summary in rm-version-switcher format
# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Box drawing characters
WIDTH=52
TOP_LEFT='┌'
TOP_RIGHT='┐'
BOTTOM_LEFT='└'
BOTTOM_RIGHT='┘'
HORIZONTAL='─'
VERTICAL='│'

# Helper function to create horizontal line
make_line() {
    local length=$1
    echo -ne "$GRAY$TOP_LEFT"
    for ((i=0; i<length-2; i++)); do
        echo -ne "$HORIZONTAL"
    done
    echo -e "$TOP_RIGHT$NC"
}

# Helper function to create bottom line
make_bottom() {
    local length=$1
    echo -ne "$GRAY$BOTTOM_LEFT"
    for ((i=0; i<length-2; i++)); do
        echo -ne "$HORIZONTAL"
    done
    echo -e "$BOTTOM_RIGHT$NC"
}

# Helper function to pad text to center it
center_text() {
    local text="$1"
    local width=$2
    local text_len=${#text}
    local padding=$(( (width - text_len - 2) / 2 ))
    local right_padding=$(( width - text_len - 2 - padding ))
    
    echo -ne "$GRAY$VERTICAL$NC"
    for ((i=0; i<padding; i++)); do echo -ne " "; done
    echo -ne "$text"
    for ((i=0; i<right_padding; i++)); do echo -ne " "; done
    echo -e "$GRAY$VERTICAL$NC"
}

# Map partitions to A/B format (p2=A, p3=B)
# Determine which partition has which version based on what's running
if [[ "${running_p:-}" == "2" ]]; then
    # Currently running p2 (A), so active_version is A, fallback_version is B
    partition_a_version="$active_version"
    partition_b_version="$fallback_version"
    partition_a_color="$GREEN"
    partition_b_color="$BLUE"
    partition_a_active="[ACTIVE]"
    partition_b_active=""
else
    # Currently running p3 (B), so active_version is B, fallback_version is A
    partition_a_version="$fallback_version"
    partition_b_version="$active_version"
    partition_a_color="$BLUE"
    partition_b_color="$GREEN"
    partition_a_active=""
    partition_b_active="[ACTIVE]"
fi

# Set next boot indicators
if [[ "${boot_p:-}" == "2" ]]; then
    partition_a_next="[NEXT BOOT]"
    partition_b_next=""
elif [[ "${boot_p:-}" == "3" ]]; then
    partition_a_next=""
    partition_b_next="[NEXT BOOT]"
else
    partition_a_next=""
    partition_b_next=""
fi

# Print title box
make_line $WIDTH
center_text "reMarkable OS Version Checker" $WIDTH
make_bottom $WIDTH

# Calculate padding for alignment
max_len=$(( ${#partition_a_version} > ${#partition_b_version} ? ${#partition_a_version} : ${#partition_b_version} ))
pad_a=$(( max_len - ${#partition_a_version} ))
pad_b=$(( max_len - ${#partition_b_version} ))

# Print partition box
make_line $WIDTH

# Build and print partition A line (always p2)
echo -ne "$GRAY$VERTICAL$NC Partition A ${GRAY}(p2)${NC}: $partition_a_color$partition_a_version$NC"
for ((i=0; i<pad_a; i++)); do printf " "; done
if [[ -n "$partition_a_active" ]]; then
    echo -ne " $GREEN$partition_a_active$NC"
fi
if [[ -n "$partition_a_next" ]]; then
    if [[ "${running_p:-}" == "2" ]]; then
        echo -ne " $GREEN$partition_a_next$NC"
    else
        echo -ne " $YELLOW$partition_a_next$NC"
    fi
fi

# Calculate remaining space and pad to right edge
# Base: "│ Partition A (p2): " = 19 characters
remaining_a=$(( WIDTH - 19 - ${#partition_a_version} - pad_a - 2 ))
if [[ -n "$partition_a_active" ]]; then remaining_a=$((remaining_a - 9)); fi
if [[ -n "$partition_a_next" ]]; then remaining_a=$((remaining_a - 12)); fi
if [[ $remaining_a -lt 1 ]]; then remaining_a=1; fi
for ((i=0; i<remaining_a; i++)); do printf " "; done
echo -e "$GRAY$VERTICAL$NC"

# Build and print partition B line (always p3)
echo -ne "$GRAY$VERTICAL$NC Partition B ${GRAY}(p3)${NC}: $partition_b_color$partition_b_version$NC"
for ((i=0; i<pad_b; i++)); do printf " "; done
if [[ -n "$partition_b_active" ]]; then
    echo -ne " $GREEN$partition_b_active$NC"
fi
if [[ -n "$partition_b_next" ]]; then
    if [[ "${running_p:-}" == "3" ]]; then
        echo -ne " $GREEN$partition_b_next$NC"
    else
        echo -ne " $YELLOW$partition_b_next$NC"
    fi
fi

# Calculate remaining space and pad to right edge
# Base: "│ Partition B (p3): " = 19 characters
remaining_b=$(( WIDTH - 19 - ${#partition_b_version} - pad_b - 2 ))
if [[ -n "$partition_b_active" ]]; then remaining_b=$((remaining_b - 9)); fi
if [[ -n "$partition_b_next" ]]; then remaining_b=$((remaining_b - 12)); fi
if [[ $remaining_b -lt 1 ]]; then remaining_b=1; fi
for ((i=0; i<remaining_b; i++)); do printf " "; done
echo -e "$GRAY$VERTICAL$NC"

make_bottom $WIDTH
