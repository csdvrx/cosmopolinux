#!/usr/bin/sh
## Copyright (C) 2023, csdvrx, MIT licensed

## Assuming a baremetal linux distribution is running, with access to efivarfs
# TODO: figure a way to do the same from Windows

## Assuming a NVMe drive, with EFI as the first partition
EFIDRIVE=/dev/nvme0n1
EFIPART=1
# TODO: should also test for sda with blkid + check the part magics for the type (EF00 on mbr)

## Add both:
# cosmopolinux default efi
# TODO: support aarch64
efibootmgr -d $EFIDRIVE -p $EFIPART -C -l "\\EFI\\cosmopolinux.efi" -L "Cosmopolinux"
# grubfm matching the arch
MACHINE=$( uname -m)
efibootmgr -d $EFIDRIVE -p $EFIPART -C -l "\\EFI\\grubfm-$MACHINE.efi" -L "GrubFM"

## Then reboot and press a hotkey (usually F12 or DEL) to select what to boot
# Not commended but could also go the bios and put GrubFM as the 1st choice
# Then use grubfm menu to go to the EFI partition and load either:
#  - for cosmopolinux, EFI/cosmopolinux.efi
#  - for windows, EFI/Microsoft/Boot/bootmgfw.ef

