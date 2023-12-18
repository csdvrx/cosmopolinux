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
#   - should use the APE loader until it can be registered with binfmc_misc
#  - doing this with no assumption is slightly complicated:
#   - the kernel can automount rootfs
#   - but automounting devtmpfs with CONFIG_DEVTMPFS_MOUNT=y requires a /dev directory
#    - there may be problems with read-only
#   - but may do even without a /dev and without initrd if being extra careful like below
#  - uses busybox for now as booting a kernel without will need some minimal features
#   - even if assuming away insmod (as modules can be static in the kernel)
#   - need to mount the filesystems (only exceptions: devtmpfs and rootfs, see below)
#   - must switch_root (utils/run_init.c in klibc) or pivot_root or chroot or at least exec within a script:
#    switch_root move the root and delete the old root directory: saves memory
#    pivot_root keeps the old root accessible under a new location
#    chroot lets you do anything you want by hand: chosen approach, passing the PID with exec

## Example with everything inside a single folder: requires care
# In qemu, try first with a display not a console (either serial or stdio) in case of kmsg issues
#  diagnose with: -display gtk,full-screen=off,gl=on,grab-on-hover=on

##### Step 1: prepare /dev and give early signs of life with kernel details
## TODO: with a cosmopolitan busybox, also use the APE loader until registered
UNAME=$( $BBPATH/uname -a )
[ -n "$UNAME" ] \
 && FROM_STAGE="from kernel $UNAME"
# no /dev unless there's an empty /dev (but that's easy mode)
# so no >/dev/kmsg below, not even trying with -f to get an some message
$BBPATH/echo "[0] stage 1 (initrd rdinit) reached $FROM_STAGE" 
# show that in the hostname
$BBPATH/hostname stage1.cosmopolinux.local
# should log the hostname change but no ./chroot/dev/ksmg yet
# this will work only if there are mknod created entries in the skeleton /dev
[ -f /dev/kmsg ] \
 && $BBPATH/echo "[1a] early kmsg proved by showing hostname" > /dev/kmsg \
 && $BBPATH/hostname > $TOKMSG \
 || $BBPATH/echo "[1a] no /dev/kmsg for early kmsg sending"
# WARNING: may not sent initial messages to kmsg until /dev used is mounted rw
# (with noinitrd and a ro rootfs, the /dev can be ro if rootfs is read-only too)
# kmsg is mostly to help debug, but we need a dev/, so prove it ASAP:
#$BBPATH/mkdir -p ./chroot/dev
$BBPATH/mount -t devtmpfs devtmpfs ./chroot/dev -o rw,nosuid,size=4096k,nr_inodes=4026374,mode=755,inode64
$BBPATH/echo "[1] /chroot/dev should now be available" > $TOKMSG

##### Step 2: prepare /proc and the chroot
#$BBPATH/mkdir -p ./chroot/proc
$BBPATH/mount -t proc none ./chroot/proc -o rw,nosuid,nodev,noexec
# binfmt for the APE loader
$BBPATH/mount -t binfmt_misc binfmt_misc ./chroot/proc/sys/fs/binfmt_misc -o rw,nosuid,nodev,noexec,relatime
# Raise printk level to show kmsg (maybe already done in the kernel cmdline)
$BBPATH/echo "6" > ./chroot/proc/sys/kernel/printk
# WONTFIX: ./chroot/usr/bin/ape-* shouldn't be present in stage 1
# yet in case of stage1+2, still check for them but hide ls errors
APES=$( $BBPATH/ls ./chroot/.ape* ./chroot/usr/bin/ape-* 2>./chroot/dev/null |$BBPATH/tr '\n' ' ')
$BBPATH/echo "[2a] APE loaders found: $APES" > $TOKMSG
MACHINE=$( ./chroot/busybox/uname -m )
# Select the best (newest) APE loader but stage 2 may chose better from /usr
APE=$( $BBPATH/ls /.ape-* 2> /dev/null | $BBPATH/sort -nr | $BBPATH/head -n 1 )
# Or hardcode a version
#APE=/.ape-1.9
$BBPATH/echo "[2b] for machine $MACHINE selected APE loader $APE" > $TOKMSG
## Register it for both MZ DOS and Mach-O, with flag F to persist in chroot
# cf https://lwn.net/Articles/679308/
# WARNING: flag for preserving argv[0] isn't supported yet
# The suffix helps in stage 2 if replacing by a better pick from /usr
[ -f ./chroot/proc/sys/fs/binfmt_misc/register ] \
 && $BBPATH/echo ":APE_early:M::MZqFpD::$APE:F" > ./chroot/proc/sys/fs/binfmt_misc/register \
 && $BBPATH/echo ":APE-jart_early:M::jartsr::$APE:F" >./chroot/proc/sys/fs/binfmt_misc/register \
 && $BBPATH/echo "[2c] APE loader registered" > $TOKMSG
# /dev/pts /sys and /tmp are nice to have but not strictly required
$BBPATH/mkdir -p ./chroot/dev/pts
$BBPATH/mount -t devpts devpts ./chroot/dev/pts -o rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=000
$BBPATH/mount -t tmpfs tmpfs ./chroot/tmp -o rw,nosuid,nodev,nr_inodes=1048576,inode64
$BBPATH/mount -t tmpfs tmpfs ./chroot/run -t tmpfs -o rw,nosuid,nodev,nr_inodes=819200,mode=755,inode64
$BBPATH/mount -t sysfs none ./chroot/sys -o rw,nosuid,nodev,noexec,relatime
$BBPATH/echo "[2] /chroot for cosmo binaries should now be prepared" > $TOKMSG

##### Step 2: prepare a few consoles to monitor stage 2+
# WARNING: busybox subshells have their standard input redirected from /dev/null
# not ./dev/null, so in stage 1, can't easily fork (background with &) until /dev ready
# also can't open spawn console getties with a full path device as they hardcode a /dev prefix
# For consoles, must chroot to fork and background with job control like
#$BBPATH/ash -c "$BBPATH/chroot ./chroot /busybox/ash -c \"/busybox/sleep 600 & \""
# FIXME: this starts 2 ash, try to do with just one

# Accessible from the console qemu is run on 
CONSOLE="hvc0"
STTYPARAMS="sane"
# WARNING: can't use stty to set anything except "sane" on hvc0
# but should be very safe given the buffer max-bytes 262144 + reports virtio-serial can go up to 1.5Gbps
$BBPATH/echo "[3a] trying $CONSOLE $STTYPARAMS" > $TOKMSG
# TODO: ash -s $CONSOLE could make it easier to find and kill it later, but may becomes blocking
$BBPATH/ash -c "$BBPATH/chroot ./chroot /busybox/ash -c \"[ -c /dev/$CONSOLE ] && /busybox/echo $CONSOLE available > /dev/kmsg && /busybox/stty -F /dev/$CONSOLE $STTYPARAMS && < /dev/$CONSOLE > /dev/$CONSOLE 2>&1 PATH=$PATH:/busybox /busybox/ash && /busybox/echo closed console $CONSOLE will not respawn > /dev/kmsg &\" -s $CONSOLE" && HVC0=/dev/hvc0

# Accessible from /dev/pts/X
CONSOLE="ttyS0"
## safe default given earlyprintk on ttyS0 and https://wiki.qemu.org/Features/ChardevFlowControl
STTYPARAMS="sane ispeed 38400 ospeed 38400"
$BBPATH/echo "[3b] trying $CONSOLE $STTYPARAMS" > $TOKMSG
$BBPATH/ash -c "$BBPATH/chroot ./chroot /busybox/ash -c \"[ -c /dev/$CONSOLE ] && /busybox/echo $CONSOLE available > /dev/kmsg && /busybox/stty -F /dev/$CONSOLE $STTYPARAMS && < /dev/$CONSOLE > /dev/$CONSOLE 2>&1 PATH=$PATH:/busybox /busybox/ash && /busybox/echo closed console $CONSOLE will not respawn > /dev/kmsg &\" -s $CONSOLE" && TTYS0=/dev/ttyS0

# Accessible from telnet localhost 7000
CONSOLE="ttyS1"
STTYPARAMS="sane ispeed 115200 ospeed 115200"
$BBPATH/echo "[3c] trying $CONSOLE $STTYPARAMS" > $TOKMSG
$BBPATH/ash -c "$BBPATH/chroot ./chroot /busybox/ash -c \"[ -c /dev/$CONSOLE ] && /busybox/echo $CONSOLE available > /dev/kmsg && /busybox/stty -F /dev/$CONSOLE $STTYPARAMS && < /dev/$CONSOLE > /dev/$CONSOLE 2>&1 PATH=$PATH:/busybox /busybox/ash && /busybox/echo closed console $CONSOLE will not respawn > /dev/kmsg &\" -s $CONSOLE" && TTYS1=/dev/ttyS1

$BBPATH/echo "[3] consoles should now be ready: $HVC0 $TTYS0 $TTYS1 (no respawn)" > $TOKMSG

# For debugging and preventing the stage 2 start
#PATH=$PATH:/$BBPATH exec $BBPATH/ash

##### Step 4: pass PID1 by exec chroot with the ./chroot prepared for stage 2
# WARNING: don't forget to pass the standard input during the exec
#exec (...) '< ./chroot/dev/console'
# Otherwise, tty will say 'not a console'
# It's nice to keep the initrd somewhere to be able to check it later
$BBPATH/mkdir ./chroot/initrd
$BBPATH/mount -o bind / ./chroot/initrd
# At this point, rdinit passes the puck to stage 2 in /chroot/
# If there's no stage 2 file, starts a shell: bash is preferred
# This is only for simplicity: could also use ./chroot/initrd/stage2.sh
CURRENT_STAGE=1
NEXT_STAGE=2
[ -f ./stage2.sh ] \
 && $BBPATH/cp ./stage2.sh ./chroot \
 && $BBPATH/echo "[4a] preparing stage 2 inside /chroot" > $TOKMSG \
 && $BBPATH/stat -c "%y %s %n" ./chroot/stage2.sh > $TOKMSG \
 && exec $BBPATH/chroot ./chroot /stage2.sh $CURRENT_STAGE $NEXT_STAGE < ./chroot/dev/console \
 || $BBPATH/echo "[4] no stage 2 due to missing ./chroot/stage2.sh, trying $APE for bash if present, defaulting to ash" > $TOKMSG \
 && [ -f $APE ] \
 && [ -f ./chroot/usr/bin/bash ] \
 && PATH=$PATH:/busybox exec $BBPATH/chroot ./chroot $APE /usr/bin/bash \
 || PATH=$PATH:/busybox exec $BBPATH/chroot ./chroot /busybox/ash

# this demonstrates how to get PID 1 with cosmopolitan bash and shows:
#  - which equivalent to busybox tools may be needed (ex: mount, chroot)
#  - allows to test them one-by-one by replacing each busybox path $BBPATH
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
# - perfect when also connected stdin to have job control
#[ -f ./chroot/usr/bin/bash ] \
# && $BBPATH/echo "[5] prefering available bash" > $TOKMSG \
# && PATH=$PATH:/busybox exec chroot ./chroot $APE /usr/bin/bash < ./chroot/dev/console \
# || PATH=$PATH:/busybox exec chroot ./chroot /busybox/ash < ./chroot/dev/console
# - perfect when also connected stdin to have job control
