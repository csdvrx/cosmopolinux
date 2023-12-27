#!/busybox/ash
## Copyright (C) 2023, csdvrx, MIT licensed
# This joins the stage 3 switchroot manually
# Helps inspect the chroot on early console terminals
#BBPATH=/busybox
# avoided symlinks on ntfs3, related to the IntxLNK+0x01+UTF-16 target path below
#BBPATH=/busybox/scripts
# simplest: use the initrd
BBPATH=/initrd/chroot/busybox
# Prefer the ape loader in /usr/bin matching the machine
MACHINE=$( $BBPATH/uname -m )
# Default to the earliest ape in / if nothing else was found
APES=$( $BBPATH/ls /switchroot/.ape* /switchroot/usr/bin/ape-* 2> /dev/null | $BBPATH/tr '\n' ' ')
[ -f /switchroot/usr/bin/ape-$MACHINE.elf ] \
 && APE=/switchroot/usr/bin/ape-$MACHINE.elf \
 || APE=$( ls /switchroot/.ape-* 2> /dev/null | $BBPATH/sort -nr | $BBPATH/head -n 1 )
APE=$( echo $APE | $BBPATH/sed -e 's|^/switchroot||' )
# To connect the stdin
TTY=$( tty )

# after switchroot, can't execute '/busybox/mount': Exec format error
# could be because ntfs symlinks contain IntxLNK+0x01+UTF-16 target path
# so "IntxLNK./busybox" unless the system attribute is activated
# with `ATTRIB +S` on windows, setfattr on linux if using ntfs-3g
# cf https://gist.github.com/Explorer09/ac4bf6838c271a9968b3
# shouldn't happen with ntfs3 but if creating symlink like test
# from within the this, the symlink is seen outside as:
# "test -> 'unsupported reparse tag 0xa000000c'"
# workaround: call busybox tools individually, like for mount:
#  /busybox/busybox mount
# here, /busybox/script is a folder of scripts used to avoid that
cat /proc/cmdline|grep rootfstype=ntfs \
 && CHROOTPREFIX="/usr/bin/env PATH=/usr/bin:$BBPATH:/busybox/scripts:/busybox" \
 && exec $BBPATH/chroot /switchroot $APE $CHROOTPREFIX  /usr/bin/bash --login < /switchroot/$TTY \
 || exec $BBPATH/chroot /switchroot $APE /usr/bin/bash < /switchroot/$TTY
