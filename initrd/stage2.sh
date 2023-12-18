#!/busybox/ash
## Copyright (C) 2023, csdvrx, MIT licensed
# The weird /busybox bangpath should prevent accidental local execution
# likewise for using $$BPATH instead of just shell internals
BBPATH=/busybox
TOKMSG=/dev/kmsg

## This is stage 2, expecting to be root and provided with /dev /proc /sys etc
# Stage 1 (rdinit with busybox) did put us in a single folder added /dev /proc /sys and did chroot
# Stage 2 (chroot on initrd) keeps using busybox until the actual root partition is found, mounted and switchroot to
# Stage 3 can then just use cosmopolitan binaries
#
# Starting from an actual Linux kernel requires minimal tools to:
#  - start the network (ip, dhcp, worse if wifi: need wpa tools)
#   -> stage 2 if need an nfsroot, stage 3 otherwise
#  - mount the filesystems (even if the module is baked in, only exceptions: devtmpfs and rootfs)
#   -> split in stage 1 (essential filesystems) and 2 (rootfs) to support cryptsetup for root on bitlocker
#  - if doing 2 stages, something like chroot/pivot_root/switch_root (cf utils/run_init.c in klibc)
#   -> here done manually as couldn't get it to work otherrwise
#  - may also want to install modules at any point (but can be avoided by including them into the kernel)
#   -> early insertion of key modules in stage 1 ensure they will be available
#   -> could be used for ZFS (could be better than NTFS for multiplatform!)

# TODO: start removing busybox from this stage 2 as more binaries are added to the cosmos
# TODO: should also facilitate local replication of the steps bringing to stage-3 even without qemu
# so add equivalent stage2 scripts:
# - for linux, bsd and macos in shell
# - for windows in powershell

# INFO: it's possible to do a very dirty debug by having a shell interrupt stage 2
# can then test things and  finish the stage2 with stage2-finish.sh on the initrd
# PATH=$PATH:/busybox exec /busybox/ash

## Announce what's happening
[ -n "$1" ] \
 && FROM_STAGE="from stage $1 going to $2"
echo "[4] stage 2 (initrd chroot) reached $FROM_STAGE" > $TOKMSG

# TODO: could prep kexec on panic 
# cf https://lkml.iu.edu/hypermail/linux/kernel/1702.2/01626.html
# will need to see the initrd and bzimage in /kernel, could use nokaslr
# cf https://wiki.gentoo.org/wiki/Kernel_Crash_Dumps

## Network and console
# could also use something like
# $BBPATH/ifconfig | $BBPATH/grep ^[a-z0-9]| $BBPATHsed -e 's/ .*//g'
IFACES=$( $BBPATH/ls /sys/class/net 2> /dev/null | $BBPATH/grep -v "^lo$" | $BBPATH/sort -nr | $BBPATH/tr '\n' ' ' )

echo "[5a] configuring network interfaces: $IFACES" > $TOKMSG
# lo should be automatic, but the others require code
# Simplish logic:
# - assume the first interfaces provides NAT using DHCP
#  - caveats for qemu: slow dhcp, and static results from built-in dhcp server
#  - always says ip=10.0.2.15 gw=10.0.0.2 dns=10.0.0.3 (optional smb=10.0.0.4)
#  - so hardcode that:
#   - if it starts with qemu prefix, assign the default ip to talk to the host
# FIXME: explore if it's possible to extend the approach to WSL
# cf https://github.com/luxzg/WSL2-fixes for a manual fix
# cf https://devblogs.microsoft.com/commandline/windows-subsystem-for-linux-september-2023-update/
#   - if it doesn't seem to belong to qemu, could be native or some other WSL thing
#   - may need extra fixes if it starts with qemu 52:54 prefix but is wsl2 (bridge mode)
# on WSL, bridging is the only way to get IPv6
#  bridging was also WSL1 default but it's said to be "harder" than NAT
# on WSL2, the default is an hyper-v virtual network adapter
#  TODO: but reports of the mac address always changing in 00:15:?? or 0e:00:00:..?
# on WSL2, can still bridge in .wslconfig:
#  networkingMode=bridged
# can also hardcode the MAC:
#  macAddress=
# disable DHCP:
#  dhcp=false
# and enable ipv6:
#  ipv6=true
# in 2023, bridges may come back after `wsl --update; wsl --update --pre-release`
#  experimental.networkingMode=mirrored
# might entail:
#  vmSwitch=WSLBridged
#  dnsTunneling=true
#  firewall=false
#  autoProxy=true
# that could mean a lot of cases to support!

# FIXME:
#$WSL2_IFACE=$( $BBPATH/ifconfig |$BBPATH/grep -i hwaddr|$BBPATH/grep "addr 0e:00:00:"|$BBPATH/sed -e 's/ .*//g')
# WSLX because either WSL1 or WSL2 bridged: then do DHCP
# will also catch qemu default configs like 52:54:00:12:34:56, but at worst will cause a small delay
#$WSLX_IFACE=$( $BBPATH/ifconfig |$BBPATH/grep -i hwaddr|$BBPATH/grep "addr 52:54:00:"|$BBPATH/sed -e 's/ .*//g')
# WONTFIX: it's extremely unlikely the mac address randomizer would give a 00 in its 1st byte but can't be sure
#$QEMU_IFACE=$( $BBPATH/ifconfig |$BBPATH/grep -i hwaddr|$BBPATH/grep "addr 52:54" | $BBPATH/grep -v"addr 52:54:00:"|$BBPATH/sed -e 's/ .*//g')
# will match both:
# the default sequential mac addrs 52:54:00:12:34:56
# and qemu-test netdev user mac addr 52:54:01:(random)
QEMU_IFACE_NAT=$( $BBPATH/ifconfig -a |$BBPATH/grep -i hwaddr |$BBPATH/grep "addr 52:54:0" |$BBPATH/sed -e 's/ .*//g' |$BBPATH/head -n 1)
# will match qemu-test tap mac addr 52:54:11:(random), the grep -v is just for safety
QEMU_IFACE_TAP=$( $BBPATH/ifconfig -a |$BBPATH/grep -i hwaddr |$BBPATH/grep "addr 52:54:1" |$BBPATH/sed -e 's/ .*//g' |$BBPATH/tail -n 1 |$BBPATH/grep -v $QEMU_IFACE_NAT)

echo "[5b] special case for qemu interfaces $QEMU_IFACE_NAT $QEMU_IFACE_TAP" > $TOKMSG
# TODO: do better than the ifconfig grep Link (dirty way to check it's here and not null)

# for qemu only, use ip=10.0.2.15 gw=10.0.0.2: it's what the pseudo-dhcp server will always give
[ -z "${QEMU_IFACE_NAT}" ] \
 && echo "[5:c-e] $QEMU_IFACE_NAT nat network interface absent" > $TOKMSG \
 || echo "[5c] assuming present $QEMU_IFACE_NAT is from qemu given ^52:54 in the mac address" > $TOKMSG \
 && $BBPATH/ifconfig -a | $BBPATH/grep -q "^$QEMU_IFACE_NAT\s*Link" \
 && echo "[5d] given 52:54:0, using deterministic IP and route" > $TOKMSG \
 && $BBPATH/ip link set $QEMU_IFACE_NAT up \
 && $BBPATH/ip addr add 10.0.2.15/24 dev $QEMU_IFACE_NAT \
 && $BBPATH/ip route add default via 10.0.2.2 \
 && echo "[5e] $QEMU_IFACE_NAT is 10.0.2.15/24, default route via 10.0.2.2" > $TOKMSG \
 || echo "[5:c-e] $QEMU_IFACE_NAT nat network configuration: failed" > $TOKMSG

# - assume the second interface sits on a private LAN to qemu, provide a fixed IP and start a DHCP server
[ -z "${QEMU_IFACE_TAP}" ] \
 && echo "[5:f-j] $QEMU_IFACE_TAP tap network interface absent" > $TOKMSG \
 || echo "[5f] assuming present last $QEMU_IFACE_TAP is from qemu given ^52:54 in the mac address" > $TOKMSG \
 && $BBPATH/ifconfig -a | $BBPATH/grep -q "^$QEMU_IFACE_TAP\s*Link" \
 && echo "[5g] using fixed IP to speedup boot" > $TOKMSG \
 && $BBPATH/ip link set $QEMU_IFACE_TAP up \
 && $BBPATH/ip addr add 172.20.20.1/16 dev $QEMU_IFACE_TAP \
 && echo "[5h] $QEMU_IFACE_TAP is 172.20.20.116" \
 && echo "[5i] adding a DHCP server" > $TOKMSG \
 && $BBPATH/dnsmasq --interface=$QEMU_IFACE_TAP --bind-interfaces --dhcp-range=172.20.20.2,172.20.20.128 \
 && echo "[5j] $QEMU_IFACE_TAP dhcp server (dnsmasq) provides leases from 172.20.20.2 to 172.20.20.128" \
 || echo "[5:f-j] $QEMU_IFACE_TAP tap network configuration: failed" > $TOKMSG

# For other interfaces, will fork the DHCP client
# TODO: that's the only for loop in these .sh, it would be nice to replace it with xarg
# FIXME: to actually use the reply, udhcpc may need a -s prog handling $1=bound
OTHER_IFACES=$( echo $IFACES | $BBPATH/sed -e "s/$QEMU_IFACE_NAT//g" -e "s/$QEMU_IFACE_TAP//g" -e 's/  */ /g' )
[ -n "${OTHER_IFACES}" ] \
 && for IFACE in $OTHER_IFACES; do
  echo "[5k1] non-qemu $IFACE: assuming it will respond to DHCP, spawning dhcpc" > $TOKMSG \
  $BBPATH/udhcpc -q -f -n -i $IFACE && \
  echo "[5k2] done with DHCP $IFACE" > $TOKMSG &
 done
echo "[5k] done with non-eqmu interfaces ($OTHER_IFACES)" > $TOKMSG

# for other qemu like bridges found on WSL1 and WSL2 post 2022, use udhcpc
# FIXME: it would be nice to be able to make assumptions, but the choice seems non-deterministic
# but within 172.16.0.0/12 ?
# can restrict the range with https://github.com/microsoft/WSL/issues/4467#issuecomment-878552365
# cf https://github.com/microsoft/WSL/issues/4601
#    https://github.com/microsoft/WSL/issues/4467
#   
#[ -n $WSLX_IFACE ] \
# && echo "assuming $WSLX_IFACE is a bridge from WSL1 or post-2022 WSL2" > $TOKMSG \
# && $BBPATH/udhcpc -q -f -n -i $QEMU_IFACE \
# && echo "$WSLX_IFACE udhcpc succeeded" > $TOKMSG

## Just for helping debug for now
$BBPATH/hostname cosmopolinux.local \
 && echo "[5l] hostname set to cosmopolinux.local" > $TOKMSG
# but for fun, need a bonjour server to map that IP on 127/8

## Do some connectivity tests, but fork them to make boot faster
# progression from just pinging NAT to a public IP to resolving as well
# the kernel boot takes about 0.9s, the sleep adds 2 seconds
# TODO: could make sleep adjustable
# so we're starting at 2.9s in dmesg relative time
# then ping waits 1s for a reply from the NAT so we're at 2.9+1=3.9s worst case
# then ping waits 2s for a reply from the public IP so we're at 2.9+2=4.9s worst case
# then ping waits 3s for a reply from the public IP so we're at 2.9+3=5.9s worst case
# this allows to estimate the TTFB:
# for now with qemu/12th gen intel about 4 seconds from boot with qemu/i7
# because 1st request fails, while the other 2 succeed so between 3.9 and 4.9
# when checking dmesg, can see more precisely:
# the request at 3.85s fails, the one at 3.95s succeeds
# It means the limiting factor for the TTFP is qemu network stack wasting about 3 seconds.
echo "[5m] in 2 seconds, testing qemu nat connectivity to 10.0.2.3 (qemu needs time)" > $TOKMSG
$BBPATH/sleep 2 \
 && $BBPATH/ping -c1 -W1 -w1 -n 10.0.2.3 > $TOKMSG 2>&1 \
 && echo "[5n] got a reply from 10.0.2.3 (qemu nat)" > $TOKMSG \
 || echo "[5n] no reply within 1 second from 10.0.2.3 (qemu nat)" > $TOKMSG \
 &

echo "[5n] in 2 seconds, testing outgoing connectivity to 1.1.1.1" > $TOKMSG
$BBPATH/sleep 2 \
 && $BBPATH/ping -c1 -W2 -w2 -n 1.1.1.1 > $TOKMSG 2>&1 \
 && echo "[5n] got a reply from 1.1.1.1" > $TOKMSG \
 || echo "[5n] no reply within 2 seconds from 1.1.1.1" > $TOKMSG \
 &

echo "[5n] in 2 seconds, testing outgoing connectivity + name resolution to google.com" > $TOKMSG
$BBPATH/sleep 2 \
 && $BBPATH/ping -c1 -W3 -w3 -n google.com > $TOKMSG 2>&1 \
 && echo "[5n] got a reply from google.com" > $TOKMSG \
 || echo "[5n] no reply within 3 second from google.com" > $TOKMSG \
 &

## TODO: could tear down stage 1 consoles, to make better ones now with getty
# but 1) will have to do the same thing again in stage 3, after switch_root
# yet 2) no agetty/getty equivalent in cosmopolitan binaries as of now
# and 3) would not be much better than stage 1 consoles: would only gain respawn
#  so 3) might as well keep an eye on the actual root view from initrd until then
#echo "[ ] starting new consoles" > $TOKMSG \
#CONSOLE=ttyS0
#PID_TTYS0=$( ps w|grep $CONSOLE|grep -v grep|sed -e 's/^  *//g' -e 's/ .*//g' )
# or with xargs
#kill $PID_TTYS0 \
# && echo "[ a] closed $CONSOLE, restarting with getty" \
# && $BBPATH/getty -H $CONSOLE -h -L -n -i -l /busybox/ash 115200,57600,38400,9600 ttyS0 vt100 \
# && /busybox/echo "closed console $CONSOLE will not respawn > /dev/kmsg" \
# && TTYS0=/dev/ttyS0 &
# WONTFIX: at this point, the connected consoles still see /switchroot
# They will be disconnected in stage 3
 
## Find the root partition and its parameters
# WONTFIX: could make that a function to iterate over other important parameters
# but should be a simple C binary, not a script: complicated and fragile
# like the pipe chain breaks with a single space at the EOL after \
# root=UUID=, rootdelay rootwait... currently not implemented
# will have to wait until stage 2 is debusyboxed
[ -f /proc/cmdline ] \
 && $BBPATH/grep -q "root=" /proc/cmdline \
 && ROOTFS=$( $BBPATH/xargs -n1 -a /proc/cmdline | $BBPATH/grep "^root=" | $BBPATH/head -n 1 | $BBPATH/sed -e 's/^root=//g')
[ -f /proc/cmdline ] \
 && $BBPATH/grep -q "rootfstype=" /proc/cmdline \
 && ROOTFSTYPE=$( $BBPATH/xargs -n1 -a /proc/cmdline | $BBPATH/grep "^rootfstype=" | $BBPATH/head -n 1 | $BBPATH/sed -e 's/^rootfstype=//g')
[ -f /proc/cmdline ] \
 && ROOTFLAGS=$( $BBPATH/xargs -n1 -a /proc/cmdline | $BBPATH/grep "^rootflags=" | $BBPATH/head -n 1 | $BBPATH/sed -e 's/^rootflags=//g')

# prepare 2 dirs, the mount arguments if available, and use these for rootfs mount
$BBPATH/mkdir -p /rootfs /switchroot
[ -n "$ROOTFSTYPE" ] && PAR_ROOTFSTYPE="-t $ROOTFSTYPE"
[ -n "$ROOTFLAGS" ] && PAR_ROOTFLAGS="-o $ROOTFLAGS"

# then check if $ROOTFS is already mounted 'somewhere' (meaning field 3 not null) to mount bind instead
echo "[6a] cmdline asked rootfs=$ROOTFS, $ROOTFSTYPE and $ROOTFLAGS" > $TOKMSG
ROOTFS_ALREADY_MOUNTED=$( $BBPATH/mount | $BBPATH/grep "$ROOTFS" | $BBPATH/sed -e 's/.*on //g' -e 's/ .*//g' | $BBPATH/head -n1)
echo "[6b] checked in mounts: if already mounted, is on '$ROOTFS_ALREADY_MOUNTED'" > $TOKMSG
echo "[6c] if already mounted: mount -o bind $ROOTFS_ALREADY_MOUNTED /rootfs" > $TOKMSG
echo "[6d] if needs new mount: mount $ROOTFS $PAR_ROOTFSTYPE $PAR_ROOTFLAGS /rootfs" > $TOKMSG

# TODO: that's like a dirty way to check for an empty/undefine, but it's more visual
$BBPATH/mount | $BBPATH/grep "^$ROOTFS_ALREADY_MOUNTED on " > $TOKMSG \
 && $BBPATH/mount -o bind $ROOTFS_ALREADY_MOUNTED /rootfs \
 && echo "[6] bind mounted root on /rootfs" > $TOKMSG \
 || $BBPATH/mount $ROOTFS $PAR_ROOTFSTYPE $PAR_ROOTFLAGS /rootfs \
 || echo "[6] ERROR: failed to mount root, starting debug" > $TOKMSG

# WONTFIX: ugly but mounting root is one of the most fragile steps, not much to do here except
# - adding a chkufsd step using the public android binaries
# - offering to debug the issue with a sane path
$BBPATH/dmesg | $BBPATH/tail -n1 | $BBPATH/grep "ERROR:" \
 && PATH=/usr/sbin:/usr/bin:/$BBPATH exec /busybox/ash

# If there's a single /chroot folder in the rootfs (as expected with ntfs), use it by default
[ -d /rootfs/chroot ] \
 && ROOTFS_DIR="/rootfs/chroot" \
 || ROOTFS_DIR="/rootfs"
echo "[7] using folder $ROOTFS_DIR within the rootfs" > $TOKMSG \

# switch_root or manual equivalents will fail if newroot is not the root of a mount
# here the ntfs fs is like the initrd: it has a separate ./chroot inside
# but can prepare /rootfs/chroot to be root of a mount named /switchroot
# TODO: a simpler recursive `mount --mount /newroot /` didn't work :
#$BBPATH/mount --move /switchroot /
# Therefore done manually:
echo "[8a] preparing mount binds of $ROOTFS_DIR to /switchroot" > $TOKMSG \
 && $BBPATH/mount -o bind $ROOTFS_DIR /switchroot \
 && $BBPATH/mount --bind /dev /switchroot/dev \
 && $BBPATH/mount --bind /dev/pts /switchroot/dev/pts \
 && $BBPATH/mount --bind /proc /switchroot/proc \
 && $BBPATH/mount --bind /proc/sys/fs/binfmt_misc /switchroot/proc/sys/fs/binfmt_misc \
 && $BBPATH/mount --bind /run /switchroot/run \
 && $BBPATH/mount --bind /tmp /switchroot/tmp \
 && $BBPATH/mount --bind /sys /switchroot/sys \
 && $BBPATH/mount --bind /initrd /switchroot/initrd \
 && $BBPATH/umount /rootfs \
 && echo "[8b] mount binds to /switchroot done" > $TOKMSG \
 || echo "[8b] ERROR: failed to mount bind the rootfs chroot/ folders, starting debug" > $TOKMSG

# WONTIFX: another ugly debug
$BBPATH/dmesg | $BBPATH/tail -n1 | $BBPATH/grep "ERROR:" \
 && PATH=/usr/sbin:/usr/bin:/$BBPATH exec /busybox/ash

# WONTFIX: regardless how, hides rootfs /chroot from mount + /proc/mounts
# cf https://unix.stackexchange.com/questions/152029/why-is-there-no-rootfs-file-system-present-on-my-system
# What will be done next depends: stage3.sh or the init=parameter
# or by default the usual "init" if present and executable in switchroot

[ -f /switchroot/stage3.sh ] \
 && [ -x /switchroot/stage3.sh ] \
 && echo "[8c] found /switchroot/stage3.sh so considering it" > /$TOKMSG \
 && echo "[8d] found /switchroot/stage3.sh executable, using it by default" > /$TOKMSG \
 && NEXT="stage3.sh" \
 && TO_STAGE=3

[ -f /switchroot/init ] \
 && [ -x /switchroot/init ] \
 && echo "[8e] found /switchroot/init so considering it" > /$TOKMSG \
 && echo "[8f] found /switchroot/init executable, overriding previous choice" > /$TOKMSG \
 && NEXT="init" \
 && TO_STAGE=I

echo "[8] going next to $NEXT in /switchroot/$NEXT as stage $TO_STAGE" > /$TOKMSG

# Can then attempt switch_root, pivot_root or chroot
# WARNING: but can't use --move /switchroot here, or will miss the leaf fs on the branch
# TODO: a simpler switch_root: `exec switch_root /newroot /sbin/init` didn't work:
#exec $BBPATH/switch_root /switchroot /.ape-1.9 /usr/bin/bash
# Could be due to the consoles still being open?
# Therefore done manually:

# List available ape loaders
APES=$( $BBPATH/ls /switchroot/.ape* /switchroot/usr/bin/ape-* 2> /dev/null | $BBPATH/tr '\n' ' ') \
 && echo "[9a] given APE loaders: $APES" > $TOKMSG
# Will prefer the ape loader matching the machine
MACHINE=$( $BBPATH/uname -m ) \
 && echo "[9b] preparing switchroot on $MACHINE as PID $$" > $TOKMSG

# Default to the earliest ape in / if nothing else was found in /usr/bin
[ -f /switchroot/usr/bin/ape-$MACHINE.elf ] \
 && APE=/switchroot/usr/bin/ape-$MACHINE.elf \
 || APE=$( $BBPATH/ls /switchroot/.ape-* 2> /dev/null | $BBPATH/sort -nr | $BBPATH/head -n 1 )

# In any case, remove the /switchroot prefix and export the choice for the next stage
export APE=$( echo $APE | $BBPATH/sed -e 's|^/switchroot||' )
echo "[9c] selected APE=$APE and exported it, now doing:" > $TOKMSG
echo "[9d] exec $BBPATH/chroot /switchroot /usr/bin/ape-$MACHINE.elf /usr/bin/bash /$NEXT" > $TOKMSG

FROM_STAGE=2
[ -f /switchroot/$APE ] \
 && echo "[9e] got $APE in /switchroot" > $TOKMSG \
 && echo $$ | $BBPATH/grep -q "^1$" \
 && echo "[9f] got PID 1" > $TOKMSG \
 && exec $BBPATH/chroot /switchroot $APE /usr/bin/bash /$NEXT $FROM_STAGE $TO_STAGE < /dev/console \
 || echo "[9e] ERROR: failed the exec chroot to switchroot folders, starting stage 2 debug" > $TOKMSG

# This demonstrates how to give PID 1 to cosmopolitan bash and shows:
#  - which equivalent to busybox tools may be needed (ex: mount, for UKI boot tweaks need efibootmgr)
#  - allows to test them one-by-one by replacing the busybox path $BBPATH by /usr/bin
#  - which tweaks may be welcomed (ex: killall won't work on unassimilated binaries due to the ape loader)

# give a shell to debug if can't get PID 1 for whatever unlikely reason
[ -f /usr/bin/bash ] \
 && echo "[9] was not PID 1 or was missing APE, starting stage 2 debug with bash if possible " > $TOKMSG \
 && [ -f $APE ] \
 && PATH=$PATH:/busybox exec $APE /usr/bin/bash \
 || PATH=$PATH:/busybox exec /busybox/ash
