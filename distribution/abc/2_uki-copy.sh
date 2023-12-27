#!/usr/bin/sh
## Copyright (C) 2023, csdvrx, MIT licensed

## Assuming a NVMe drive
# TODO: should also test for sda with blkid + check the part magics for the type (EF00 on mbr)
## Mount the partition
# TODO: don't assum /boot/efi exists but try to use it
# TODO: use an alternative path to /mnt like `mkdir -p /var/run/efi`
# not just if /boot/efi is not mounted and /mnt doesn't exist, but as /mnt could be already used differently
mount /dev/nvme0n1p1 /mnt
## Add the right grubfm, even if may not be needed should be small enough
MACHINE=$( uname -m)
cp grubfm-$MACHINE.efi /mnt/EFI/
# TODO: a1ive grubfm is now deprecated, fix ventoy for standalone use (without hardcoded partition boundaries)
#cf https://github.com/ventoy/Ventoy/issues/1342
# TODO: an efi chainloader like rufus adding support for the other FS drivers would be smaller and better
#cf https://efi.akeo.ie/ https://github.com/pbatard/efifs 
# could then have both cosmopolinux.iso and ventoy.efi or grubfm.efi on the NTFS parittion to save space on the EFI
# should be /EFI/BootXX using case..esac for $MACHINE
#cf https://www.rodsbooks.com/efi-bootloaders/installation.html#alternative-naming
## Add cosmopolinux to the EFI
# TODO: add support for creating cosmopolinux.iso for C:\ along with C:\cosmopolinux when NTFS-Bitlocker is ready
cp cosmopolinux.efi /mnt/EFI/
## Umount the partition
umount /mnt
