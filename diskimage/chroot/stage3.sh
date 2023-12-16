#!/usr/bin/bash
## Copyright (C) 2023, csdvrx, MIT licensed
# This is stage3, unlike stage1.sh and stage2.sh, no weird bangpath above
# Made in pure bash as simple as possible, to be used outside cosmopolinux
# Within cosmopolinux, has stage: $1 $2 and best APE loader: $APE

# use kmsg if detected stage change + uid 0 with just the available cosmo tools
[ -n "$1" ] && [ -n "$2" ] \
 && FROM_STAGE="from stage $1 going to $2" \
 && id | sed -e 's/gid.*//g' | grep "id=0" \
 && [ -f /dev/kmsg ] \
 && echo -n "[9] stage 3 (bash) reached ${FROM_STAGE}" > /dev/kmsg \
 || echo "[9] stage 3 (bash) reached ${FROM_STAGE}"

# explain what's happening, as everything will use /.ape if not assimilated
echo
echo "Currently running $0 $*"
echo
echo "You have gcc, git, redbean (etc) cosmopolitan binaries to play with"
echo 
#  TODO: configure vim, rsync with example, tmux
#  TODO: add to cosmopolitan superconfigure:
#   - network tools: mutt, w3m, dropbear
#   - cmdline: rg, fzf, mc/nnn, eza, par2, color hexdump/hexedit binaries 
#   - boot tools: efibootmgr, objcopy to recreate UKI
#   - basic tools through dropbox (currently just a static amd64 binary)

# TODO: can't execute '/busybox/mount': Exec format error
# However, '/busybox/busybox mount' works
# Seems due to ntfs symlinks having IntxLNK+0x01+UTF-16 target path
# so "IntxLNK./busybox" unless the system attribute is activated
# with `ATTRIB +S` on windows, setfattr on linux if using ntfs-4g
# cf https://gist.github.com/Explorer09/ac4bf6838c271a9968b3
# shouldn't happen with ntfs3 but if creating symlink like /bin
# seen outside as "bin -> 'unsupported reparse tag 0xa000000c'"
# workaround: call busybox tools individually, like for mount:
#  /busybox/busybox mount
# here, /busybox/script is a folder of scripts used to avoid that
cat /proc/cmdline|grep rootfstype=ntfs \
 && PATH=/busybox/scripts:$PATH

# FIXME: bash complains:
#cannot set terminal process group (-1): Not a typewriter
#no job control in this shell
# seems due to the lack of controlling terminal
# could also be caused by set options

## When, PID 1 using a respawning approach. Maybe overkill
# However I don't like kernel panic "Attempted to kill init!"

# WARNING: here, shouldn't use the ape loader
#command="$APE ./usr/bin/bash"
command="./usr/bin/bash"

# TODO: start bash within nice multiplexed environment
# FIXME: if trying to starting tmux here, stops with fork failed: operation not permitted
# FIXME: if reptyr of the existing ash, may need `echo 0 > /proc/sys/kernel/yama/ptrace_scope`
# to avoid reptyr: Unable to attach to pid X: Operation not permitted
# also required for gdb, strace, etc. to attach to non-children unless uid 0

respawner() {
 # primitive respawn of the command + trap
 "$command"
 restart_command() {
  echo "unless receiving SIGINT Ctrl+C, $$ will respawn $command in a second"
  sleep 1
  respawner
 }
 # signals are always blocked while the handler is running
 stop_command() {
  echo "got SIGINT, killing $pid"
  kill -9 $pid
  # handle second Ctrl+C
  restart_command
 }
 # handle first signal (can include bash internal DEBUG ERR RETURN)
 # trap will return from the handler
 # but after the command called when the handler was invoked
 trap stop_command SIGINT HUP QUIT ABRT TERM RETURN
 #wait $command_pid # this would be blocking
 echo "return code: $?"
 restart_command
}

# save the pid
pid=$$
[ "${pid}" == 1 ] \
 && echo "Starting $command with exit protection as PID 1 ($pid) to avoid killing init" \
 && respawner \
 || echo "Not PID 1 but $pid, starting $command" \
 && $command

# Hopefully, will only come there if kill -9 the main pid
echo "Cleaning up" > /dev/kmsg \
 && rm -f /.bash_history /.viminfo

# TODO: still, can kernel panic, so use kexec crash protection to restart

