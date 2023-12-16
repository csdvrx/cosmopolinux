#!./chroot/busybox/ash
## Copyright (C) 2023, csdvrx, MIT licensed
# The weird bangpath should prevent accidental local execution
# likewise for using $$BPATH instead of just shell internals
BBPATH=./chroot/busybox
# avoid using /dev in case it's read-only, even if this dev/ contains a few devices
TOKMSG=./chroot/dev/kmsg
# not using ttyprintk to be visible on hvc0 and the serial consoles

## This is stage 1
# rdinit from initramfs 
#  - will need in ./chroot the essential filesystems
#  - so mount /proc, /dev, /sys and /tmp in that folder
#  - doing this with no assumption is slightly complicated:
#   - the kernel can automount rootfs
#   - but automounting devtmpfs with CONFIG_DEVTMPFS_MOUNT=y requires a /dev directory
#    - there may be problems with read-only
#   - but may do even without a /dev and without initrd if being extra careful like below
#  - uses busybox for now as booting a kernel without will need some minimal features
#   - even if assuming away insmod (as modules can be static in the kernel)
#   - need to mount the filesystems (only exceptions: devtmpfs and rootfs, see below)
#   - must switch_root (utils/run_init.c in klibc) or pivot_root or chroot or at least exec within a script

## Example with everything inside a single folder: requires care
# In qemu, try first with a display not a console (either serial or stdio) in case of kmsg issues
#  diagnose with: -display gtk,full-screen=off,gl=on,grab-on-hover=on
UNAME=$( $BBPATH/uname -a )
[ -n "$UNAME" ] \
 && FROM_STAGE="from kernel $UNAME"
# no /dev unless there's an empty /dev (but that's easy mode)
# so no >/dev/kmsg below, not even trying with -f to get an some message
$BBPATH/echo "[0] stage 1 (initrd rdinit) reached $FROM_STAGE" 
# show that in the hostname
$BBPATH/hostname stage1.cosmopolinux.local
# should log the hostname change but no ./chroot/dev/ksmg
# but will work only if there are mknod created entries in the skeleton /dev
[ -f /dev/kmsg ] \
 && $BBPATH/echo "[1a] early kmsg proved by showing hostname" > /dev/kmsg \
 && $BBPATH/hostname > $TOKMSG \
 || $BBPATH/echo "[1a] no /dev/kmsg for early kmsg sending"
## kmsg is mostly to help debug
$BBPATH/mount -t devtmpfs devtmpfs ./chroot/dev -o rw,nosuid,size=4096k,nr_inodes=4026374,mode=755,inode64
$BBPATH/echo "[1] /chroot/dev/kmsg is now available" > $TOKMSG
$BBPATH/mount -t proc none ./chroot/proc -o rw,nosuid,nodev,noexec
# immediately increase the printk level if not already done through the kernel cmdline
$BBPATH/echo "6" > ./chroot/proc/sys/kernel/printk

# /dev/pts /sys and /tmp re nice to have but not required
$BBPATH/mkdir -p ./chroot/dev/pts
$BBPATH/mount -t devpts devpts ./chroot/dev/pts -o rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=000
$BBPATH/mount -t tmpfs tmpfs ./chroot/tmp -o rw,nosuid,nodev,nr_inodes=1048576,inode64
$BBPATH/mount -t tmpfs tmpfs ./chroot/run -t tmpfs -o rw,nosuid,nodev,nr_inodes=819200,mode=755,inode64
$BBPATH/mount -t sysfs none ./chroot/sys -o rw,nosuid,nodev,noexec,relatime
# WONTFIX: ./chroot/usr/bin/ape-* shouldn't be present in stage 1
# but in case of stage1+2, check for them and hide ls errors
APES=$( $BBPATH/ls ./chroot/.ape* ./chroot/usr/bin/ape-* 2>./chroot/dev/null |$BBPATH/tr '\n' ' ')
MACHINE=$( ./chroot/busybox/uname -m )
$BBPATH/echo "[2a] uname: $UNAME" > $TOKMSG
$BBPATH/echo "[2] /chroot prepared on $MACHINE with APE loaders present: $APES" > $TOKMSG
# consoles cant block but cant fork nicely without /dev in busybox as it needs /dev/null: must chroot to bg fork like
#$BBPATH/ash -c "$BBPATH/chroot ./chroot /busybox/ash -c \"/busybox/sleep 600 & \""
# yet consoles are helpful for qemu etc so worth the chroot effort (careful: they use /dev/kmsg)

# WARNING: busybox subshells have their standard input redirected from /dev/null
# this means in in stage 1, can't easily fork (background with &) without having /dev/null
# also can't open spawn console getties with a full path device as they hardcode a /dev prefix
# may not sent initial messages to /dev/kmsg until the /dev used is mounted rw
# (with noinitrd and a ro rootfs, the /dev can be ro if rootfs is read-only too)

CONSOLE="hvc0"
STTYPARAMS="sane"
# can't use stty to set anything except "sane" on hvc0
# but should be very safe given the buffer max-bytes 262144 + reports virtio-serial can go up to 1.5Gbps
$BBPATH/echo "[3a] trying $CONSOLE $STTYPARAMS" > $TOKMSG
# TODO: ash -s $CONSOLE could make it easier to find and kill it later, but may becomes blocking
$BBPATH/ash -c "$BBPATH/chroot ./chroot /busybox/ash -c \"[ -c /dev/$CONSOLE ] && /busybox/echo $CONSOLE available > /dev/kmsg && /busybox/stty -F /dev/$CONSOLE $STTYPARAMS && < /dev/$CONSOLE > /dev/$CONSOLE 2>&1 PATH=$PATH:/busybox /busybox/ash && /busybox/echo closed console $CONSOLE will not respawn > /dev/kmsg &\" -s $CONSOLE" && HVC0=/dev/hvc0

CONSOLE="ttyS0"
## safe default given earlyprintk on ttyS0 and https://wiki.qemu.org/Features/ChardevFlowControl
STTYPARAMS="sane ispeed 38400 ospeed 38400"
$BBPATH/echo "[3b] trying $CONSOLE $STTYPARAMS" > $TOKMSG
$BBPATH/ash -c "$BBPATH/chroot ./chroot /busybox/ash -c \"[ -c /dev/$CONSOLE ] && /busybox/echo $CONSOLE available > /dev/kmsg && /busybox/stty -F /dev/$CONSOLE $STTYPARAMS && < /dev/$CONSOLE > /dev/$CONSOLE 2>&1 PATH=$PATH:/busybox /busybox/ash && /busybox/echo closed console $CONSOLE will not respawn > /dev/kmsg &\" -s $CONSOLE" && TTYS0=/dev/ttyS0

CONSOLE="ttyS1"
STTYPARAMS="sane ispeed 115200 ospeed 115200"
$BBPATH/echo "[3c] trying $CONSOLE $STTYPARAMS" > $TOKMSG
$BBPATH/ash -c "$BBPATH/chroot ./chroot /busybox/ash -c \"[ -c /dev/$CONSOLE ] && /busybox/echo $CONSOLE available > /dev/kmsg && /busybox/stty -F /dev/$CONSOLE $STTYPARAMS && < /dev/$CONSOLE > /dev/$CONSOLE 2>&1 PATH=$PATH:/busybox /busybox/ash && /busybox/echo closed console $CONSOLE will not respawn > /dev/kmsg &\" -s $CONSOLE" && TTYS1=/dev/ttyS1

$BBPATH/echo "[3] consoles spawned once: $HVC0 $TTYS0 $TTYS1" > $TOKMSG

# For debugging before stage 2 starts
#PATH=$PATH:/$BBPATH exec $BBPATH/ash

# It's nice to keep the initrd somewhere to be able to check it later
$BBPATH/mkdir ./chroot/initrd
$BBPATH/mount -o bind / ./chroot/initrd

# At this point, rdinit passes the puck to stage 2 in /chroot/
# if there's no stage 2 file, starts a shell: bash is preferred
# This is only for simplicity: could also use ./chroot/initrd/stage2.sh
CURRENT_STAGE=1
NEXT_STAGE=2
[ -f ./stage2.sh ] \
 && $BBPATH/cp ./stage2.sh ./chroot \
 && $BBPATH/echo "[4a] preparing stage 2 inside /chroot" > $TOKMSG \
 && $BBPATH/stat -c "%y %s %n" ./chroot/stage2.sh > $TOKMSG \
 && exec $BBPATH/chroot ./chroot /stage2.sh $CURRENT_STAGE $NEXT_STAGE \
 || $BBPATH/echo "[4] no stage 2 due to missing ./chroot/stage2.sh, trying $APE for bash if present, defaulting to ash" > $TOKMSG \
 && [ -f /usr/bin/ape-$MACHINE.elf ] \
 && [ -f ./chroot/usr/bin/bash ] \
 && PATH=$PATH:/busybox exec $BBPATH/chroot ./chroot /usr/bin/ape-$MACHINE.elf /usr/bin/bash \
 || PATH=$PATH:/busybox exec $BBPATH/chroot ./chroot /busybox/ash

# there's no /usr folder in initrd but this demonstrates how to get PID 1 in cosmopolitan bash and shows:
#  - which equivalent to busybox tools may be needed (ex: mount, uefibootmgr for UKI boot later)
#  - allows to test them one-by-one by replacing the busybox path $BBPATH by /usr/bin
#  - which tweaks may be welcomed (ex: killall won't work on unassimilated binaries due to the ape loader)

# Can also try other approaches, with APE=/usr/bin/ape-$MACHINE.elf like:
# - can fork a busybox with the path to help debugging
#PATH=$PATH:/busybox /chroot/busybox/ash -c "$BBPATH/chroot ./chroot /busybox/ash"
# - can start bash
#PATH=$PATH:/busybox exec chroot ./chroot $APE /usr/bin/bash
# - can exec busybox as pid 1
#PATH=$PATH:/chroot/busybox exec ./chroot/busybox/ash
# - better in ./chroot where /dev /proc and the others directories are
#PATH=$PATH:/busybox exec chroot ./chroot /busybox/ash
# - even better to use bash as we have cosmopolitan tools in ./chroot/usr
#PATH=$PATH:/busybox chroot ./chroot /busybox/ash -c "exec /usr/bin/bash"
# - elegant when also getting PID 1 by loading with ape to execv
#PATH=$PATH:/busybox exec chroot ./chroot $APE /usr/bin/bash
# - more elegant when bailing out to ash in case of problem (as above)
#[ -f ./chroot/usr/bin/bash ] \
# && $BBPATH/echo "[5] prefering available bash" > $TOKMSG \
# && PATH=$PATH:/busybox exec chroot ./chroot $APE /usr/bin/bash \
# || PATH=$PATH:/busybox exec chroot ./chroot /busybox/ash
