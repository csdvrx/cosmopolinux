#!/usr/bin/bash
## Copyright (C) 2023, csdvrx, MIT licensed
# This is stage 3, no ./ in the bangpath to be usable outside cosmopolinux
# Within cosmopolinux:
#  - gets the chosen best ape loader as an environment variable: $APE
#  - has stage information if loaded from earlier stages: from=$1 to=$2
#  - handles reboot by going into stage 9

## Avoid WSL and Ubuntu "going apeshit" but do that intelligently:
# "Think about the order of adding entries! Later added entries are matched first!"
#cf https://docs.kernel.org/admin-guide/binfmt-misc.html
# Can use the format :name:type:offset:magic:mask:interpreter:flags 
# WSL used:
#echo ':WSLInterop:M::MZ::/init:' > /proc/sys/fs/binfmt_misc/register
# WSL with systemd uses:
#echo :WSLInterop-late:M::MZ::/init:P > /proc/sys/fs/binfmt_misc/register
# The F flag is important to run in a chroot that may hide this path
#cf https://github.com/systemd/systemd/issues/28126#issuecomment-1603028661
#cf https://github.com/microsoft/WSL/issues/8843#issuecomment-1837264576
## WARNING: may have wanted to fix by:
# WSL:
#[ -f /proc/sys/fs/binfmt_misc/WSLInterop-late ] \
# && echo '-1' > /proc/sys/fs/binfmt_misc/WSLInterop-late
#[ -f /proc/sys/fs/binfmt_misc/WSLInterop ] \
# && echo '-1' > /proc/sys/fs/binfmt_misc/WSLInterop
# Ubuntu:
#[ -f /proc/sys/fs/binfmt_misc/cli ] \
# && echo '-1' >/proc/sys/fs/binfmt_misc/cli
# Or by going nuclear and disabling it all:
#[ -f /proc/sys/fs/binfmt_misc/status ] \
# && echo '-1' >/proc/sys/fs/binfmt_misc/status
## But can do better, and fix both WSL Ubuntu by leaving things as-is and add:
[ -z "${MACHINE}" ] \
 && [ -x ./usr/bin/uname ] \
 && export MACHINE=$( ./usr/bin/uname -a )
[ -z "${APE}" ] \
 && [ -f "./usr/bin/ape-${APE}.elf" ] \
 && APE="./usr/bin/ape-${APE}.elf"
[ -f "${APE}" ] \
 && [ -f /proc/sys/fs/binfmt_misc/register ] \
 && [ "$(ls /proc/sys/fs/binfmt_misc/APE*| wc -l)" -le 1 ] \
 && DOBINFMT=1
[ -n "${DOBINFMT}" ] \
 && id | sed -e 's/gid.*//g' | grep "id=0" \
 && echo ":APE:M::MZqFpD::$APE:" >/proc/sys/fs/binfmt_misc/register \
 && echo ":APE-jart:M::jartsr::$APE:" >/proc/sys/fs/binfmt_misc/register

## Use kmsg if with just the available tools detects stage change + uid 0
# iff a kernel is used (check args: from+to), stage 9 will reboot cleanly
# TODO: may later support namespaces, will have to fix the detection
# for ex by checking the hostname is cosmopolinux (will need extra tools)
[ -n "$1" ] && [ -n "$2" ] \
 && FROM_STAGE="from stage $1 going to $2" \
 && [ -x /initrd/stage9.sh ] \
 && export FINAL_STAGE="exec /initrd/stage9.sh" \
 || export FINAL_STAGE="echo 'outside cosmopolinux; not rebooting'"
[ -n "${FROM_STAGE}" ] \
 && id | sed -e 's/gid.*//g' | grep "id=0" \
 && [ -f /dev/kmsg ] \
 && echo -n "[9] stage 3 (bash) reached ${FROM_STAGE}" > /dev/kmsg \
 || echo "[9] stage 3 (bash) reached ${FROM_STAGE}"

# Check the standard input is connected and explain what's happening
TTY=$( tty )
# This tty check avoids errors due to a missing stdin fd like:
#no job control in this shell
# they are due to lack of stdin, so doing job control with set -m can't help
#cannot set terminal process group (-1): Not a typewriter
# cf https://github.com/fabric/fabric/issues/395#issuecomment-32219270
# cf https://www.linuxjournal.com/content/job-control-bash-feature-you-only-think-you-dont-need
echo
echo "Currently running '$0 $*' as pid $$ on tty $TTY"
echo
echo "You have opt/cosmocc opt/git and other cosmopolitan binaries to play with"
echo 
# TODO: configure vim, rsync with example, tmux
# TODO: add to cosmopolitan superconfigure:
#  - network tools: mutt, w3m, dropbear
#  - cmdline: rg, fzf, mc/nnn, eza, par2, color hexdump/hexedit binaries 
#  - boot tools: efibootmgr, objcopy to recreate UKI
#  - basic tools through dropbox (currently just a static amd64 binary)

# WONTFIX: can't execute '/busybox/mount': Exec format error
# However, '/busybox/busybox mount' works
# Seems due to ntfs symlinks having IntxLNK+0x01+UTF-16 target path
# so "IntxLNK./busybox" unless the system attribute is activated
# with `ATTRIB +S` on windows, setfattr on linux if using ntfs-4g
# cf https://gist.github.com/Explorer09/ac4bf6838c271a9968b3
# shouldn't happen with ntfs3 but if creating symlink like /bin
# seen outside as "bin -> 'unsupported reparse tag 0xa000000c'"
# workaround: call busybox tools individually, like for mount:
#  /busybox/busybox mount
# initrd is kept, so should prefix by /initrd/chroot/busybox/
cat /proc/cmdline|grep -q rootfstype=ntfs \
 && [ -d /initrd/chroot/busybox/ ] \
 && PATH=$PATH:/initrd/chroot/busybox/
 # also have /busybox/script, a folder of scripts (not symlinks)
cat /proc/cmdline|grep -q rootfstype=ntfs \
 && [ -d /busybox/scripts ] \
 && PATH=$PATH:/busybox/scripts

## When, PID 1 using a respawning approach. Maybe overkill
# However I don't like kernel panics like "Attempted to kill init!"
# The command will be prefixed by $APE read from the environment
command="./usr/bin/bash"
# --login will make the shell interactive, helps for job control
parameters="--login -i"

# TODO: start bash within nice multiplexed environment like tmux
# FIXME: cosmopolitan tmux problem: stops with fork failed: operation not permitted
# TODO: if using reptyr to grab existing pids, will need `echo 0 > /proc/sys/kernel/yama/ptrace_scope`
# otherwise: Unable to attach to pid X: Operation not permitted
# also required for gdb, strace, etc. to attach to non-children unless uid 0

# functions to pass the name of the signal
trap_with_arg () {
  func="$1" ; shift
  for sig ; do
    trap "$func $sig" "$sig"
  done
}

# primitive respawn of the command + trap
respawner() {
 # TODO: decide if it's a bad idea to use the APE loader here
 $APE $command $parameters < /dev/console
 restart_command() {
  echo "unless receiving a signal like SIGINT (Ctrl+C), $$ will respawn $APE $command $parameters < /dev/console in 2 seconds"
  echo "with a signal, instead of respawning, will run $FINAL_STAGE"
  # list traps
  #trap
  # if within cosmopolinux, using a kernel, allow reboots
  # if the sleep is interrupted, run this reboot command
  sleep 2 || $FINAL_STAGE || echo "problem"
  respawner
 }
 # signals are always blocked while the handler is running
 stop_command() {
  # handle second Ctrl+C, but only seen once when killing from terminal
  kill -9 $pid
  restart_command
 }
 # handle first signal
 # (can include bash internal DEBUG ERR RETURN)
 # trap will return from the handler
 # but after the command called when the handler was invoked
 trap_with_arg stop_command SIGINT HUP ABRT RETURN QUIT TERM RETURN
 # list traps:
 #trap
 echo "return code: $?"
 restart_command
}

# FIXME: job control problems, doing set -m here doesn't help
# save the pid, mention the stdin redirection is outside the parameters
pid=$$
[ "${pid}" == 1 ] \
 && echo "As PID 1, starting with exit protection '$APE $command $parameters < /dev/console' to avoid killing init" \
 && echo "For backgrounding with &, enable job control with: set -m" \
 && respawner \
 || echo "Starting normally '$APE $command $parameters' without any special protection" \
 && $APE $command $parameters

# TODO: make sure it can't here anymore? In case it does, remove temp files:
echo "BUG: left stage 3, please report how it happened" > /dev/kmsg \
 && rm -f ./.bash_history ./.viminfo ./.bash_history-cosmopolinux.db-journal

# TODO: still, could have a kernel panic, so should use kexec crash protection:
# could restart when using a kernel + debug the crashed one
