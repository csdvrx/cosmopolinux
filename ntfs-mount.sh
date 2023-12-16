#!/usr/bin/sh
TARGET=cosmopolinux.qcow2
MOUNTPOINT=/ntfs
NETBLOCKDEV=nbd0
# For paragon mkntfs
#MKNTFSOPTION="-v:Cosmopolinux"
# For ntfs3 mktfs
MKNTFSOPTION="-L:Cosmopolinux"

# create a sparse image (nbd is better than dd and losetup)
# then format it with either paragon ntfs tool or ntfs-3g
# mount, rsync and umount
[ ! -f $TARGET ] \
 && echo "missing $TARGET" \
 && exit 0

modprobe nbd \
 && qemu-nbd -c /dev/$NETBLOCKDEV $TARGET \
 && mount /dev/$NETBLOCKDEV $MOUNTPOINT

# TODO: deploy with rsync
#(...)
exit

# TODO prepare a zip that can be deployed to a NTFS partition

# close the image
time sync \
 && umount $MOUNTPOINT \
 && qemu-nbd -d /dev/$NETBLOCKDEV
