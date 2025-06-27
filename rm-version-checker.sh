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
cat << EOF
→ Active:    p$running_p
→ Fallback:  p$other_p
→ Next boot: p$boot_p

Version (Active):     $active_version
Version (Fallback):   $fallback_version
Version (Next boot):  $boot_version
EOF

# 9. Cleanup
umount "$mnt"
rmdir "$mnt"
