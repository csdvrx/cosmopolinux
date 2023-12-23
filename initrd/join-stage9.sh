#!/initrd/chroot/busybox/ash
## Copyright (C) 2023, csdvrx, MIT licensed
# The weird long bangpath is necessary to run from either stage3+ or earlier

## This enters stage 9 by sending kill signals to what pid 1 runs in rootfs
# Figure out where /proc is, the choices are very limited
[ -d /proc ] \
 && PROCPATH="/proc"
[ -d /chroot/proc ] \
 && [ -z $PROCPATH ] \
 && PROCPATH="/chroot/proc"
# Find the rootfs, as `readlink -f` returns a path from within the chroot
# otherwise, ` ...| grep -q "/switchroot"` will only works in a serial console
ROOTFS=$( xargs -n1 -a $PROCPATH/cmdline | grep "^root=" | head -n 1 | sed -e 's/^root=//g')

# sigterm first, then 1 second sleep to save files
ROOTFSPIDS=$(
 for p in $PROCPATH/[0-9]* ; do \
  [ -f $p/exe ] && grep " $( readlink -f $p/cwd) " /proc/mounts | grep -q "$ROOTFS" \
  && grep -q -v "stage9" $p/cmdline && echo "$p" | sed -e 's/\/proc\///g' | sort -n -r | grep -v "^1$" | tr '\n' ' ' \
 ; done \
 )
ROOTFSCMDS=$( echo $ROOTFSPIDS | tr ' ' '\n' | grep "^[0-9][0-9]*$" | xargs -I {} cat /proc/{}/cmdline | tr '\0' ',' | tr '\n' ';' )
echo $ROOTFSPIDS | grep -q "[0-9]" \
 && echo $ROOTFSPIDS | tr ' ' '\n' |  grep "^[0-9][0-9]*$" | xargs -I {} kill {}
echo "sigterm killing softly the pids bound to $ROOTFS: $ROOTFSPIDS ($ROOTFSCMDS)" > /dev/kmsg
# 1 second sleep
sleep 1

## sigkill twice within 1 second, to bypass pid 1 stage 3 respawner protector
# because of its form `sleep 1 && echo "respawning" || exec stage9`
# below, excludes pid 1 from the ROOTFSPIDS with `grep -v "^1$"`
ROOTFSPIDS=$(\
 for p in $PROCPATH/[0-9]* ; do \
  [ -f $p/exe ] && grep " $( readlink -f $p/cwd) " /proc/mounts | grep -q "$ROOTFS" \
  && [ $( wc -c < $p/cmdline ) -gt 0 ] \
  && grep -q -v "stage9" $p/cmdline && echo "$p" | sed -e 's/\/proc\///g' | sort -n -r | grep -v "^1$" | tr '\n' ' ' \
 ; done \
 )
# show context, so see if including by mistake some the wrong commands
ROOTFSCMDS=$( echo $ROOTFSPIDS | tr ' ' '\n' | grep "^[0-9][0-9]*$" | xargs -I {} cat /proc/{}/cmdline | tr '\0' ',' |
tr '\n' ';' )
echo $ROOTFSPIDS | grep -q "[0-9]" \
 && echo $ROOTFSPIDS | tr ' ' '\n' |  grep "^[0-9][0-9]*$" | xargs -I {} kill -9 {}
echo "sigkill once the pids bound to $ROOTFS: $ROOTFSPIDS ($ROOTFSCMDS)" > /dev/kmsg

## Must do the second kill -9 within 1 second: can't join stage 9 if has below:
##sleep 1
#sleep 10
#
#ROOTFSPIDS=$(\
# for p in $PROCPATH/[0-9]* ; do \
#  [ -f $p/exe ] && grep " $( readlink -f $p/cwd) " /proc/mounts | grep -q "$ROOTFS" \
#  && [ $( wc -c < $p/cmdline ) -gt 0 ] \
#  && grep -q -v "stage9" $p/cmdline && echo "$p" | sed -e 's/\/proc\///g' | sort -n -r | grep -v "^1$" | tr '\n' ' ' \
# ; done \
# )
## show context, so see if including by mistake some the wrong commands
#ROOTFSCMDS=$( echo $ROOTFSPIDS | tr ' ' '\n' | grep "^[0-9][0-9]*$" | xargs -I {} cat /proc/{}/cmdline | tr '\0' ',' |
#tr '\n' ';' )
#echo $ROOTFSPIDS | grep -q "[0-9]" \
# && echo $ROOTFSPIDS | tr ' ' '\n' |  grep "^[0-9][0-9]*$" | xargs -I {} kill -9 {}
#echo "sigkilled twice: $ROOTFSPIDS" > /dev/kmsg
