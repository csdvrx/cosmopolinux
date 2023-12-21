#!/usr/bin/bash
## Copyright (C) 2023, csdvrx, MIT licensed

## This is stage9, the conclusion of all stages ending with a reboot

TOKMSG=/dev/kmsg

## Use a fixed custom path prefering /usr if possible
# symlinks on ntfs3 cause problems with busybox so they are last
PATH=/usr/bin:/busybox/scripts:/initrd/chroot/busybox/scripts

## Enable the magic sysrq to later ask an immediate reboot
[ -d /proc/sys/kernel ] \
 && echo 1 > /proc/sys/kernel/sysrq \
 && echo "[9a] enabled sysrq" > $TOKMSG \
 || echo "[9a] problem enabling sysrq" > $TOKMSG

## Find where the rootfs partition is mounted
# should be / if in stage3
# could be /switchroot if in early stages
[ -f /proc/cmdline ] \
 && grep -q "root=" /proc/cmdline \
 && ROOTFS=$( xargs -n1 -a /proc/cmdline | grep "^root=" | head -n 1 | sed -e 's/^root=//g') \
 && echo "[9b] found cmdline rootfs on $ROOTFS" > $TOKMSG \
 || echo "[9b] problem finding rootfs device" > $TOKMSG

# Alternatively, could find which partition is ntfs3, but less flexible
[ -n $ROOTFS ] \
 && ROOTMOUNT=$( mount | grep $ROOTFS | sed -e 's/ type.*//' -e 's/.* on //g') \
 && echo "[9c] found cmdline root mounted on $ROOTFS" > $TOKMSG \
 || echo "[9c] problem finding root mount" > $TOKMSG

## Remount the root partition as read-only
[ -n $ROOTMOUNT ] \
 && mount -n -o remount,ro $ROOTMOUNT \
 && echo "[9d] remounted $ROOTMOUNT as read-only" > $TOKMSG \
 || echo "[9d] problem remounting to read-only" > $TOKMSG

## Ask sysrq for an immediate reboot
mount |grep $ROOTFS | grep "(ro" \
 && echo b > /proc/sysrq-trigger \
 || echo "[9] failed to reboot" > $TOKMSG
