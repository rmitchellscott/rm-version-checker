#!/bin/bash
set -e

# 1. What device+partition is running?
running_dev=$(rootdev)                  # e.g. /dev/mmcblk2p2
running_p=${running_dev##*p}            # “2”

# 2. Derive the block-device base (everything before the “p2”)
base_dev=${running_dev%p*}              # e.g. /dev/mmcblk2

# 3. Figure out the other partition
other_p=$(( running_p == 2 ? 3 : 2 ))

echo "→ Active:   $running_dev (p$running_p)"
echo "→ Fallback: ${base_dev}p$other_p (p$other_p)"
echo

# 4. Read & clean version on the active root
active_version=$(grep '^REMARKABLE_RELEASE_VERSION=' /usr/share/remarkable/update.conf \
                 | cut -d= -f2)
echo "Version on p$running_p (active):   $active_version"

# 5. Mount & clean version on the fallback root
mnt=$(mktemp -d)
mount -o ro "${base_dev}p${other_p}" "$mnt"
fallback_version=$(grep '^REMARKABLE_RELEASE_VERSION=' "$mnt/usr/share/remarkable/update.conf" \
                   | cut -d= -f2)
echo "Version on p$other_p (fallback): $fallback_version"

# 6. Cleanup
umount "$mnt"
rmdir "$mnt"
