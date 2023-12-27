#!/initrd/chroot/busybox/ash
## Copyright (C) 2023, csdvrx, MIT licensed
# The weird long bangpath is necessary to run from either stage3+ or earlier:
# stage 3 has problems with busybox symlinks on NTFS3, so use ash from initrd

## This is stage 9, the final stage that will end with a reboot
# But might refuse and exit if the conditions are not right for a reboot

## Use a fixed custom path prefering /usr if possible
# because busybox symlinks cause problems on ntfs3, they are last
PATH=/usr/bin:/busybox/scripts:/chroot/busybox/scripts:/busybox:/chroot/busybox

# Don't run if called from outside cosmopolinux to avoid accidental reboots
#hostname | grep -q cosmopolinux || exit 0

## Figure out where to send the output
# for stage 3
[ -c /dev/kmsg ] \
 && TOKMSG=/dev/kmsg
# for stage 1
[ -z "$TOKMSG" ] \
 && [ -c /chroot/dev/kmsg ] \
 && TOKMSG=/chroot/dev/kmsg
# in case kmsg is missing from the kernel
[ -z "$TOKMSG" ] \
 && [ -c /dev/console ] \
 && TOKMSG=/dev/console
# same as above
[ -z "$TOKMSG" ] \
 && [ -c /chroot/dev/console ] \
 && TOKMSG=/chroot/dev/console
# if nothing else works, can allow a silent execution
[ -z "$TOKMSG" ] \
 && [ -c /dev/null ] \
 && TOKMSG=/dev/null
[ -z "$TOKMSG" ] \
 && [ -c /chroot/dev/null ] \
 && TOKMSG=/chroot/dev/null
# but f there's no device at all, something is wrong, so bail out
[ -z "$TOKMSG" ] \
 && echo "no TOKMSG" \
 && exit 1

# 2 scenarios: called manually, or called by a staging script
[ -n "$1" ] \
 && FROM_STAGE="by $0 from stage $1 going to $2" \
 || FROM_STAGE="by $0 started with no argument" \

## So announce the scenario
echo "[10a] as pid $$, entering the final stage $FROM_STAGE, output to $TOKMSG" > $TOKMSG \
 || echo "[10a] as pid $$, entering the final stage $FROM_STAGE, output to $TOKMSG failed"

# Figure out where /proc is, the choices are very limited
# - default for stage 3
[ -d /proc ] \
 && PROCPATH="/proc"
# - in earlier stages 1-2, so a valid alternative to allow reboot there
[ -d /chroot/proc ] \
 && [ -z $PROCPATH ] \
 && PROCPATH="/chroot/proc"
# WONTFIX: no /proc in /initrd while needed by `mount` so can't do mount|grep
# but if there's no usable directory, bail out: needed for cmdline and reboot
[ ! -d $PROCPATH ] \
 && echo "no proc directory" > $TOKMSG \
 && exit 2
## When announcing proc, if can't redirect output, bail out
echo "[10b] will use proc from $PROCPATH" > $TOKMSG \
 || exit 3

# If no proc and can't mount proc in a directory, also bail out: same as above
[ -d $PROCPATH/sys/kernel ] \
 || mount -t proc none $PROCPATH -o rw,nosuid,nodev,noexec \
 || exit 4

## Share what is known about the mount
echo "[10c] full list of mounts:" > $TOKMSG
cat $PROCPATH/mounts > $TOKMSG 2>&1

## Find the rootfs device and its mount
# with $PROCPATH/mounts, doesn't need procfs to be mounted in /proc 
# WARNING: ROOTFSMOUNT fails if using / instead of | in the regex
# ROOTFSMOUNT and PID1DEV can be empty when using initrd:
#  (- ROOTDEV will be rootfs, the name of initrd)
#  (- ROOTFSMOUNT empty is normal if unmounted, due to grep "^$ROOTFS ")
#  - PID1DEV not normal: can't get initrd from a serial terminal either, like:
#  `readlink -v /proc/95/cwd  -f` returns / while we are in /chroot
#  FIXME: find a way to match the chroot device or path, or recode to /initrd/chroot when null
[ -f $PROCPATH/cmdline ] \
 && grep -q "root=" $PROCPATH/cmdline \
 && ROOTFS=$( xargs -n1 -a $PROCPATH/cmdline | grep "^root=" | head -n 1 | sed -e 's/^root=//g') \
 && ROOTFSMOUNT=$( cat $PROCPATH/mounts | grep "^$ROOTFS " | sed -e "s|^$ROOTFS ||g" -e 's/ .*//g' ) \
 && PID1DEV=$( cat $PROCPATH/mounts | grep " $(readlink -f /proc/1/cwd) " | sed -e 's/ .*//g' || echo initrd) \
 && ROOTDEV=$( cat $PROCPATH/mounts | grep " / " | sed -e 's/ .*//g' || echo "initrd" ) \
 && echo "[10d] cmdline ROOTFS=$ROOTFS on ROOTFSMOUNT=$ROOTFSMOUNT, PID1DEV=$PID1DEV, /=ROOTDEV=$ROOTDEV" > $TOKMSG \
 || echo "[10d] problem finding ROOTFS=$ROOTFS or ROOTFSMOUNT=$ROOTFSMOUNT or PID1DEV=$PID1DEV or /=ROOTDEV=$ROOTDEV" > $TOKMSG

# When debugging, seeing what's available can help
#[ -d /dev ] && ls /dev
#[ -d /initrd/chroot/dev ] && ls /initrd/chroot/dev
#which sh
#ls -la $( which sh )

## Enable the magic sysrq to later ask an immediate reboot
[ -d $PROCPATH/sys/kernel ] \
 && echo 1 > $PROCPATH/sys/kernel/sysrq \
 && echo "[10e] enabled sysrq" > $TOKMSG \
 || echo "[10e] problem enabling sysrq" > $TOKMSG

## Check arguments in case being called by a stage script (or even by itself!)
# should reboot only if rootfs is read only, or if rootfs it no longer mounted
# but can't test that due to missing /proc like in stage 1, so check stages:
# from 9 to 9 = can reboot right now, because already cleaned up
[ -n "$1" ] \
 && [ $1 -eq 9 ] \
 && [ $2 -eq 9 ] \
 && echo "[10] rebooting now $FROM_STAGE with $PROCPATH/sysrq-trigger" > $TOKMSG \
 && echo b > $PROCPATH/sysrq-trigger

## Make a list of the processes still running there to try to kill them
# This is in case they save their state to a file before the remount
# WARNING: readlink -f is as seen as from the chroot: /switchroot is / in stage3
# so can't do `grep -q "^/switchroot"` or will only work from serial consoles
# resolve to a device, as switchroot maps to ntfs3: `(...) | grep -q "$ROOTFS"`
# TODO: try to remove the for loop in ROOTFSPIDS
ROOTFSPIDS=$(\
 for p in $PROCPATH/[0-9]* ; do \
  [ -f $p/exe ] && grep " $( readlink -f $p/cwd) " /proc/mounts | grep -q "$ROOTFS" \
  && [ $( wc -c < $p/cmdline ) -gt 0 ] \
  && grep -q -v "stage9" $p/cmdline && echo "$p" | sed -e 's/\/proc\///g' | sort -n -r | grep -v "^1$" | tr '\n' ' ' \
 ; done \
 )
# show context, so see if including by mistake some the wrong commands
ROOTFSCMDS=$( echo $ROOTFSPIDS | tr ' ' '\n' | grep "^[0-9][0-9]*$" | xargs -I {} cat /proc/{}/cmdline | tr '\0' ',' | tr '\n' ';' )

## Try to kill them nicely to allow them to save their state to rootfs (rw)
# Show this list, should at least have pid 1 if still in switchroot
# FIXME: killing a process that doesn't exist seems to stop everything
# WARNING: in stage 3, can fail if using the wrong sh (due to ntfs3 symlink)
echo $ROOTFSPIDS | grep -q "[0-9]" \
 && echo "[10f1] pid $$ preparing kill of $ROOTFSPIDS ($ROOTFSCMDS)" > $TOKMSG \
 && echo $ROOTFSPIDS | tr ' ' '\n' |  grep "^[0-9][0-9]*$" | grep -v "^1$" | xargs -I {} sh -c "[ -d /proc/{} ] && kill {}" \
 && echo "[10f] pid $$ sent kill (once) to $ROOTFSPIDS" > $TOKMSG \
 || echo "[10f] pid $$ has nothing to kill" > $TOKMSG

##&& echo $ROOTFSPIDS | tr ' ' '\n' |  grep "^[0-9][0-9]*$" | grep -v "^1$" | xargs -I {} kill {} \

## Wait 1 second in case running processes need to save some files
# TODO: look for opened files to avoid waiting for no good reason
echo "[10g] pid $$ waiting 1 second before attempting kill -9 of leftover pids" > $TOKMSG \
 && sleep 1

## List the pids leftover after the kill attempt for information
LEFTOVERS=$( echo $ROOTFSPIDS | tr ' ' '\n' | grep "^[0-9][0-9]*$" | xargs -I {} sh -c "[ -d /proc/{} ] && echo {}" | tr '\n' ' ' )
LEFTOVERSCMD=$( echo $ROOTFSPIDS | tr ' ' '\n' | grep "^[0-9][0-9]*$" | xargs -I {} sh -c "[ -d /proc/{} ] && cat /proc/{}/cmdline | tr '\0' ',' && echo" | tr '\n' ';' )
[ -n "$LEFTOVERS" ] \
 && echo "[10h] pid $$ after kill, leftover processes $LEFTOVERS ($LEFTOVERSCMD)" > $TOKMSG \
 || echo "[10h] pid $$ no process left behind after kill" > $TOKMSG

## Forcefully kill any leftover pid
ROOTFSPIDS=$(\
 for p in $PROCPATH/[0-9]* ; do \
  [ -f $p/exe ] && grep " $( readlink -f $p/cwd) " /proc/mounts | grep -q "$ROOTFS" \
  && grep -q -v "stage9" $p/cmdline && echo "$p" | sed -e 's/\/proc\///g' | sort -n -r | grep -v "^1$" | tr '\n' ' ' \
 ; done \
 )
# show context, so see if including by mistake some the wrong commands
ROOTFSCMDS=$( echo $ROOTFSPIDS | tr ' ' '\n' | grep "^[0-9][0-9]*$" | xargs -I {} cat /proc/{}/cmdline | tr '\0' ',' | tr '\n' ';' )
echo $ROOTFSPIDS | grep -q "[0-9]" \
 && echo $ROOTFSPIDS | tr ' ' '\n' |  grep "^[0-9][0-9]*$" | grep -v "^1$" | xargs -I {} kill -9 {} \
 && echo "[10i] pid $$ sent kill (twice) -9 (once) to $ROOTFSPIDS ($ROOTFSCMDS)" > $TOKMSG \
 || echo "[10i] pid $$ has nothing to kill (twice) -9 (once)" > $TOKMSG

## List again after the kill -9 the pids leftover, for information
LEFTOVERS=$( echo $ROOTFSPIDS | tr ' ' '\n' | grep "^[0-9][0-9]*$" | xargs -I {} sh -c "[ -d /proc/{} ] && echo {}" | tr '\n' ' ' )
# FIXED: the null byte was not replaced below
#LEFTOVERSCMD=$( echo $ROOTFSPIDS | tr ' ' '\n' | grep "^[0-9][0-9]*$" | xargs -I {} sh -c "[ -d /proc/{} ] && cat /proc/{}/cmdline | tr '\0' ' ' | sed -e 's/ .*//g'" | tr ' ' ',' )
LEFTOVERSCMD=$( echo $ROOTFSPIDS | tr ' ' '\n' | grep "^[0-9][0-9]*$" | xargs -I {} sh -c "[ -d /proc/{} ] && cat /proc/{}/cmdline | tr '\0' ',' && echo" | tr '\n' ';' )
[ -n "$LEFTOVERS" ] \
 && echo "[10j] pid $$ after kill, leftover processes $LEFTOVERS ($LEFTOVERSCMD)" > $TOKMSG \
 || echo "[10j] pid $$ no process left behind after kill" > $TOKMSG

## If not pid 1, repeat the kill -9 within 1 second to bypass the respawner of pid 1
# because of its form `sleep 1 && echo "respawning" || exec stage9`
# good because pid 1 may succeed in unmounting the rootfs (here can't do it)
# and read-only not enough for some fs who save their own umount (zfs export)
ROOTFSPIDS=$(\
 for p in $PROCPATH/[0-9]* ; do \
  [ -f $p/exe ] && readlink -f $p/cwd |grep -q "$ROOTFS" \
  && grep -q -v "stage9" $p/cmdline && echo "$p" | sed -e 's/\/proc\///g' | sort -n -r | grep -v "^1$" | tr '\n' ' ' \
 ; done \
 )
# show context, so see if including by mistake some the wrong commands
ROOTFSCMDS=$( echo $ROOTFSPIDS | tr ' ' '\n' | grep "^[0-9][0-9]*$" | xargs -I {} cat /proc/{}/cmdline | tr '\0' ',' | tr '\n' ';' )
[ "$$" -ne "1" ] \
 && echo $ROOTFSPIDS | grep -q "[0-9]" \
 && echo $ROOTFSPIDS | tr ' ' '\n' |  grep "^[0-9][0-9]*$" | grep -v "^1$" | xargs -I {} kill -9 {} \
 && echo "[10k] pid $$ sent kill (thrice) -9 (twice) to $ROOTFSPIDS ($ROOTFSCMDS)" > $TOKMSG \
 || echo "[10k] pid $$ has no need to send kill (thrice) -9 (twice)" > $TOKMSG

## If not pid 1, try to let it do its job: it may unmount the rootfs, we can't
[ "$$" == 1 ] \
 && echo "[10l] pid $$ continuing without delay" > $TOKMSG \
 || echo "[10l] pid $$ sleeping for 1 seconds" > $TOKMSG
[ "$$" == 1 ] \
 || sleep 1

## Remount the root partition as read-only to avoid being marked dirty + fsck
[ -n "$ROOTFSMOUNT" ] \
 && mount -n -o remount,ro $ROOTFSMOUNT \
 && echo "[10m] pid $$ remounted $ROOTFSMOUNT as read-only" > $TOKMSG \
 || echo "[10m] pid $$ problem remounting to read-only" > $TOKMSG

## To enter the final stage that will cause a reboot, 2 acceptable conditions:
# - rootfs was remounted read-only
# - rootfs was fully unmounted: not done here
# Regardless of pid, will try to umount as many other fs that are not needed:
# so not /proc (proc) /dev (devtmpfs) or /initrd (rootfs), but nothing more
# WONTFIX: can't do recursive umount (-r) then direct reboot: no -r in busybox
# reentering stage9 from initrd is safer: can cleanly unmount any leftover

OTHERFS=$( mount | sed -e 's/.* type //g' -e 's/ .*//g' | sort | uniq | grep -v proc | grep -v devtmpfs | grep -v rootfs | tr '\n' ',' | sed -e 's/,$//g')
[ -n "$OTHERFS" ] \
 && echo "[10n1] pid $$ will unmount others fs: $OTHERFS" > $TOKMSG \
 && umount -f -v -a -t $OTHERFS > $TOKMSG 2>&1 \
 && echo "[10n] unmounted most, leftover mounts:" > $TOKMSG \
 && mount > $TOKMSG 2>&1 \
 || echo "[10n] pid $$ did not unmount all others fs" > $TOKMSG

echo "[10o1] pid $$ checking if rootfs read-only" > $TOKMSG \
 && mount |grep -q "$ROOTFS.*(ro" \
 && echo "[10o] pid $$ rootfs read only, reentering stage 9 in initrd" > $TOKMSG \
 && exec chroot /initrd /chroot/busybox/busybox ash /stage9.sh 9 9 \
 || echo "[10o] pid $$ rootfs not readonly, can't reentering stage 9 in initrd" > $TOKMSG \

## Regardless of the pid, could ask for an immediate reboot if ROOTFS is gone
# would have been faster that reentering stage 9, but bad idea
#mount |grep -q "$ROOTFS" \
# && echo "[10p] still has rootfs, can't directly reboot" > $TOKMSG \
# || echo b > $PROCPATH/sysrq-trigger

## If not pid 1, could do a delayed reboot (deadman trigger) if ROOTFS is ro
# because if pid 1 is still using /switchroot, can't do anything about it 
# but bad idea too: some fs need not just read-only but export before reboot
[ "$$" -ne 1 ] \
 && echo "[10p2] pid $$ has rootfs read-only, 4 seconds deadman trigger " > $TOKMSG \
 && sleep 4 \
 && echo "[10p] pid $$ deadman trigger reached, rebooting now" > $TOKMSG \
 && echo b > $PROCPATH/sysrq-trigger \
 || echo "[10p] pid $$ not doing the deadman trigger" > $TOKMSG \
 &

