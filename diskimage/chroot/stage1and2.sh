#!./chroot/busybox/ash
# Copyright (C) 2023, csdvrx, MIT licensed

## This is stage1 + a minimal stage2 for booting straight from the ntfs partition with no initrd
#
# Most of the early support is done by klibc (kinit, ipconfig, nfsmount...)
#  - see Documentation/driver-api/early-userspace/early_userspace_support.rst
#  - the kernel can automount rootfs
#  - but automounting devtmpfs with CONFIG_DEVTMPFS_MOUNT=y requires a /dev directory
#  - but may do even without a /dev and without initrd if being extra careful like below
#
# For now use busybox: booting a kernel without will need some minimal features
#  - even if assuming away insmod (as modules can be static in the kernel)
#  - need to mount the filesystems (only exceptions: devtmpfs and rootfs, see below)
#  - must switch_root (utils/run_init.c in klibc) or pivot_root or chroot or at least exec within a script

## Example without an initrd: everything inside a single folder requires care
# In qemu, try first with a display not a console (either serial or stdio) in case of kmsg issues
#  -display gtk,full-screen=off,gl=on,grab-on-hover=on
BBPATH=./chroot/busybox

$BBPATH/echo "[0] ntfs stage1 with stage2 starting" # no /dev unless there's an empty /dev (but that's easy mode)
$BBPATH/mount -t devtmpfs devtmpfs ./chroot/dev -o rw,nosuid,size=4096k,nr_inodes=4026374,mode=755,inode64
$BBPATH/echo "[1] /chroot/dev/kmsg is available" > ./chroot/dev/kmsg
$BBPATH/mount -t proc none ./chroot/proc -o rw,nosuid,nodev,noexec
# /dev/pts /sys and /tmp re nice to have but not required
$BBPATH/mkdir -p ./chroot/dev/pts
$BBPATH/mount -t devpts devpts ./chroot/dev/pts -o rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=000
$BBPATH/mount -t tmpfs tmpfs ./chroot/tmp -o rw,nosuid,nodev,nr_inodes=1048576,inode64
$BBPATH/mount -t tmpfs tmpfs ./chroot/run -o rw,nosuid,nodev,nr_inodes=819200,mode=755,inode64
$BBPATH/mount -t sysfs none ./chroot/sys -o rw,nosuid,nodev,noexec,relatime
# WONTFIX: ./chroot/usr/bin/ape-* shouldn't be present in stage 1
# but in case of stage1+2 from the ntfs, list them and hide ls errors
APES=$( $BBPATH/ls ./chroot/.ape* ./chroot/usr/bin/ape-* 2>./chroot/dev/null |$BBPATH/tr '\n' ' ')
# Prefer the ape loader in ./chroot/usr/bin matching the machine
# Default to the earliest ape in ./chroot if nothing else was found
[ -f ./chroot/usr/bin/ape-$MACHINE.elf ] \
 && APE=./chroot/usr/bin/ape-$MACHINE.elf \
 || APE=$( ls ./chroot/.ape-* 2> /dev/null | $BBPATH/sort -nr | $BBPATH/head -n 1 )
# In any case, remove the ./chroot prefix
APE=$( echo $APE | $BBPATH/sed -e 's|^./chroot||' )

MACHINE=$( ./chroot/busybox/uname -m )
$BBPATH/echo "[2] /chroot prepared on $MACHINE with APE loaders present: $APES" > $TOKMSG
# consoles cant block but cant fork without /dev in busybox as it needs /dev/null: must chroot to bg fork like
#$BBPATH/ash -c "$BBPATH/chroot ./chroot /busybox/ash -c \"/busybox/sleep 600 & \""
# yet consoles are helpful for qemu etc so worth the effort

CONSOLE="hvc0"
STTYPARAMS="sane"
# can't use stty to set anything except "sane" on hvc0
# but should be very safe given the buffer max-bytes 262144 + reports virtio-serial can go up to 1.5Gbps
$BBPATH/echo "[3a] trying $CONSOLE $STTYPARAMS" > ./chroot/dev/kmsg
# show a summary of what happened so far in case the first console is blocking
# WONTFIX: could prefix invidual $CONSOLE available with \[3x\] to help tracing
# but using special chars in this nested mess of shell scripts may be too risky
$BBPATH/ash -c "$BBPATH/chroot ./chroot /busybox/ash -c \"[ -c /dev/$CONSOLE ] && /busybox/echo $CONSOLE available > /dev/kmsg && /busybox/stty -F /dev/$CONSOLE $STTYPARAMS && < /dev/$CONSOLE > /dev/$CONSOLE 2>&1 PATH=$PATH:/busybox /busybox/ash && /busybox/echo closed console $CONSOLE will not respawn > /dev/kmsg &\"" && HVC0=/dev/hvc0

CONSOLE="ttyS0"
## safe default given earlyprintk on ttyS0 and https://wiki.qemu.org/Features/ChardevFlowControl
STTYPARAMS="sane ispeed 38400 ospeed 38400"
$BBPATH/echo "[3b] trying $CONSOLE $STTYPARAMS" > ./chroot/dev/kmsg
$BBPATH/ash -c "$BBPATH/chroot ./chroot /busybox/ash -c \"[ -c /dev/$CONSOLE ] && /busybox/echo $CONSOLE available > /dev/kmsg && /busybox/stty -F /dev/$CONSOLE $STTYPARAMS && < /dev/$CONSOLE > /dev/$CONSOLE 2>&1 PATH=$PATH:/busybox /busybox/ash && /busybox/echo closed console $CONSOLE will not respawn > /dev/kmsg &\"" && TTYS0=/dev/ttyS0

CONSOLE="ttyS1"
STTYPARAMS="sane ispeed 115200 ospeed 115200"
$BBPATH/echo "[3c] trying $CONSOLE $STTYPARAMS" > ./chroot/dev/kmsg
$BBPATH/ash -c "$BBPATH/chroot ./chroot /busybox/ash -c \"[ -c /dev/$CONSOLE ] && /busybox/echo $CONSOLE available > /dev/kmsg && /busybox/stty -F /dev/$CONSOLE $STTYPARAMS && < /dev/$CONSOLE > /dev/$CONSOLE 2>&1 PATH=$PATH:/busybox /busybox/ash && /busybox/echo closed console $CONSOLE will not respawn > /dev/kmsg &\"" && TTYS1=/dev/ttyS1

$BBPATH/echo "[3] consoles spawned once: $HVC0 $TTYS0 $TTYS1" > $TOKMSG

# For debugging before stage 2 starts
#PATH=$PATH:/$BBPATH exec $BBPATH/ash

################### Pseudo stage 2 ######################

MACHINE=$( ./chroot/busybox/uname -m )
$BBPATH/echo "[4] finished consoles, preparing pid 1 for $MACHINE" > ./chroot/dev/kmsg

# Could havePID  1, so try to exec to keep it
[ -f ./chroot/usr/bin/bash ] \
 && $BBPATH/echo "[5] prefering available bash" > ./chroot/dev/kmsg \
 && PATH=$PATH:/busybox exec chroot ./chroot $APE /usr/bin/bash \
 || PATH=$PATH:/busybox exec chroot ./chroot /busybox/ash

# The above gives cosmopolitan bash in PID 1 and shows:
#  - which equivalent to busybox tools may be needed (ex: mount)
#  - allows to test them one-by-one by replacing the busybox path $BBPATH by /usr/bin
#  - which tweaks may be welcomed (ex: killall won't work on unassimilated binaries due to the ape loader)
# Can also try other simpler, with APE=/usr/bin/ape-$MACHINE.elf like:
#
# can fork a busybox with the path to help debugging
#PATH=$PATH:/busybox /chroot/busybox/ash -c "$BBPATH/chroot ./chroot /busybox/ash"
# then start bash
#PATH=$PATH:/busybox exec chroot ./chroot $APE /usr/bin/bash
# can exec busybox as pid 1
#PATH=$PATH:/chroot/busybox exec ./chroot/busybox/ash
# better in ./chroot where /dev /proc and the others directories are
# PATH=$PATH:/busybox exec chroot ./chroot /busybox/ash
# even better to use bash as we have cosmopolitan tools in ./chroot/usr
#PATH=$PATH:/busybox chroot ./chroot /busybox/ash -c "exec /usr/bin/bash"
# elegant when also getting PID 1 by loading with ape to execv
#PATH=$PATH:/busybox exec chroot ./chroot $APE /usr/bin/bash
# more elegant when bailing out to ash in case of problem
