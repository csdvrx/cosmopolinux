These instructions are a WIP. When NTFS bitlocker is supported, the suggested default will be to use a directory on C:\ which will be faster


(0. Check the kernel options that'll be made from ./cmdline.sh)

1. Create cosmopolinux UKI from ./cmdline.sh ../kernel.bzImage (FIXME: add ../initrd.cpio.gz, support aarch64 kernel compilation)

    ./1_uki-create.sh cosmopolinux.efi

2. Place cosmopolinux UKI and the grubfm matching your machine arch in your EFI boot partition

2a. Can do that either on Linux:

2a1. Automatically with a script:

    ./2_uki-copy.sh

2a2. Alternatively, can do that manually:

    mount /dev/nvme0n1p1 /mnt
    MACHINE=$( uname -m)
    cp grubfm-$MACHINE.efi /mnt/EFI/
    cp cosmopolinux.efi /mnt/EFI/
    umount /mnt

NB: it's NOT recommended, but on x86-64, you could also use grubfm as your default EFI loader, replacing Windows bootmgfw.efi (TODO: see if can offer similar steps to replace MacOS on aarch64 if Asahi can) with:

    mount /dev/nvme0n1p1 /mnt
    mv /mnt/EFI/Boot/bootx64.efi /mnt/EFI/Boot/windows.efi
    cp grubfm-x86_64.efi /mnt/EFI/Boot/bootx64.efi
    umount /mnt

2b. On Windows, manually:

    diskpart
    sel disk 0
    sel part 1
    detail par

If the GPI partition matches the EFI UUID C12A7328-F81F-11D2-BA4B-00A0C93EC93B (or the MBR magic matches EF00):

    assign letter=s:
    mountvol S: /s

Then from a command line, a powershell or a filemanager with administrative permissions, add the files to S:\EFI\

    copy grubfm-x86_64.efi S:\EFI
    copy cosmopolinux.efi S:\EFI

3. Add to your UEFI an entry either:

3a. From Linux, either:

3a1. Automatically with:

    3_uki-install-fromlinux.sh

3b1. Manully, with either or both of:

3b1a. grubfm.efi (to be able to select either cosmopolinux.efi or windows.efi) from a Ubuntu Live matching your machine:

    MACHINE=$( uname -m)
    efibootmgr -d /dev/nvme0n1 -p 1 -C -l "\\EFI\\grubfm-$MACHINE.efi" -L "GrubFM"

(TODO: figure how to do that from Windows with winload.exe that reads the BCD to load the kernel (ntoskrnl.exe)

3b1b. ccosmopolinux.efi for direct and faster boot (FIXME: for now, the kernel is x86-64 only, add compile scripts to support both x86-64 and aarch64)

    efibootmgr -d /dev/nvme0n1 -p 1 -C -l "\\EFI\\cosmopolinux.efi" -L "Cosmopolinux"

3b. From Windows, either:

3a1. TODO: figure how to do that from Windows with a Powershell script

3b2. Manually with [EasyUEFI](https://www.easyuefi.com/index-us.html)

4. Create a 1G partition by shrinking existing partitions and creating a new one in the freed space

4a. On Linux (TODO: document how to shrink an ext4 partitions on Linux (not possible with xfs or zfs) then how to create a partition)

4b. On Windows (TODO: document how to shrink C:\ in Windows to create a L: partition)

5. Write cosmopolinux.efi to the 1G partition you created, either:

5a. On Linux on the device (/dev) corresponding to this nth partition (example: n=9) of the first (0th) nvme drive first (1st) namespace (therefore /dev/nvme0n1p9):

    cat ../cosmopolinux.ntfs3 > /dev/nvme0n1p9

5b. On Windows (TODO: document how to write it with Win32DiskImager)

6. Reboot and select the UEFI entry you created (GrubFM or Cosmopolinux)

WARNING: This a WIP, please report any bug to help improve cmdline.sh
