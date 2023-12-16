#!/usr/bin/sh
SIZE=1G
TARGET=cosmopolinux.qcow2
MOUNTPOINT=/ntfs
NETBLOCKDEV=nbd0
# For paragon mkntfs
#MKNTFSOPTION="-v:Cosmopolinux"
# For ntfs3 mktfs
MKNTFSOPTION="-L:Cosmopolinux"

[ -f $TARGET ] \
 && echo "not overwriting existing $TARGET" \
 && exit 0

CREATE="qemu-img create -f qcow2 $TARGET $SIZE \
 && modprobe nbd \
 && qemu-nbd -c /dev/$NETBLOCKDEV $TARGET"
CLOSE="qemu-nbd -d /dev/$NETBLOCKDEV"
# creating a sparse image may be better than dd and losetup in the future
# but less portable:
#  need to cat the nbd0 etc

CREATE="dd if=/dev/zero of=$TARGET bs=$SIZE count=1 && losetup $TARGET /dev/loop2"
CLOSE="losetup -d /dev/loop2"

# then format it with either paragon ntfs tool or ntfs-3g
FORMAT="mkntfs $MKNTFSOPTION /dev/$NETBLOCKDEV"

# create, format mount, rsync and umount
$CREATE && $FORMAT && mount /dev/$NETBLOCKDEV $MOUNTPOINT

# TODO: deploy binaries from diskimage with rsync, add dirs and dotsfiles
#(...)
exit

# TODO prepare a zip that can be deployed to a NTFS partition

# close the image
time sync \
 && umount $MOUNTPOINT \
 $CLOSE
