#!/bin/bash
set -e

# 1. Determine the running device+partition (e.g. /dev/mmcblk2p2)
running_dev=$(rootdev)
running_p=${running_dev##*p}    # "2"

# 2. Derive the block-device base (everything before the "p2")
base_dev=${running_dev%p*}          # e.g. /dev/mmcblk2

# 3. Figure out the other (fallback) partition
other_p=$(( running_p == 2 ? 3 : 2 ))

# 4. Get next boot partition from U-Boot env
boot_p=$(fw_printenv active_partition 2>/dev/null | cut -d= -f2 || echo "unknown")

# 5. Read & clean version on the active root
active_version=$(grep '^REMARKABLE_RELEASE_VERSION=' /usr/share/remarkable/update.conf \
                 | cut -d= -f2)

# 6. Mount & clean version on the fallback root
mnt=$(mktemp -d)
mount -o ro "${base_dev}p${other_p}" "$mnt"

# Set up cleanup trap to ensure umount/rmdir always run
cleanup() {
  umount "$mnt" 2>/dev/null || true
  rmdir "$mnt" 2>/dev/null || true
}
trap cleanup EXIT

fallback_version=$(grep '^REMARKABLE_RELEASE_VERSION=' "$mnt/usr/share/remarkable/update.conf" \
                   | cut -d= -f2)

# 7. Determine version for next boot partition
if [[ "$boot_p" == "$running_p" ]]; then
  boot_version=$active_version
elif [[ "$boot_p" == "$other_p" ]]; then
  boot_version=$fallback_version
else
  boot_version="unknown"
fi

# 8. Print summary
# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Determine colors and next boot indicators
if [[ "$boot_p" == "$running_p" ]]; then
  active_color="$GREEN"
  active_suffix=" (next boot)"
else
  active_color="$GREEN"
  active_suffix=""
fi

if [[ "$boot_p" == "$other_p" ]]; then
  fallback_color="$YELLOW"
  fallback_suffix=" (next boot)"
else
  fallback_color="$BLUE"
  fallback_suffix=""
fi

printf "Active:     p%-2s   ${active_color}%s%s${NC}\n" "$running_p" "$active_version" "$active_suffix"
printf "Fallback:   p%-2s   ${fallback_color}%s%s${NC}\n" "$other_p" "$fallback_version" "$fallback_suffix"
