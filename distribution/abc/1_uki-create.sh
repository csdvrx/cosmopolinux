#!/usr/bin/sh
## Copyright (C) 2023, csdvrx, MIT licensed

PREFIX="cosmopolinux"

## Check the local version
# From the running kernel
#VERSIONLOCALVERSION=$( uname -r )
# From the compiled /kernel
#VERSION=$( grep "Kernel Configuration$" /kernel/.config |sed -e 's/ Kernel Configuration//g' -e 's/.* //g')
#LOCALVERSION=$( grep ^CONFIG_LOCALVERSION /kernel/.config |sed -e 's/"$//g' -e 's/.*"//g' )
#VERSIONLOCALVERSION="$VERSION$LOCALVERSION"
# From the copied bzImage
VERSIONLOCALVERSION=$( file ../kernel.bzImage |sed -e 's/.*version //g' -e 's/ .*//g' )
# From an hardcoded string
#VERSIONLOCALVERSION="6.2.2-nohz_full"

## UKI defaults to $PREFIX-$VERSIONLOCALVERSION.efi, but also take a filename argument to override
[ -z "$1" ] && OUTFILE="$PREFIX-$VERSIONLOCALVERSION.efi" || OUTFILE="$1"

CMDOUT="./cmdline.txt"
KERNEL="../kernel.bzImage"
INITRD="../initrd.cpio.gz"
# systemd EFI stub
SDSTUB="./linuxx64.efi.stub"

## Create a cmdline, the assemble the UKI if everything works (files present, non zero length etc)
sh cmdline.sh > $CMDOUT \
 && [ -s $CMDOUT ] \
 && echo -n "Start: " && date && echo "Adding:" \
 && stat -c "%y %s %n" $CMDOUT $KERNEL $INITRD \
 && echo objcopy \
    --add-section .osrel="./os-release" --change-section-vma .osrel=0x20000 \
    --add-section .cmdline="$CMDOUT"  --change-section-vma .cmdline=0x30000 \
    --add-section .linux="$KERNEL"    --change-section-vma .linux=0x2000000 \
    "$SDSTUB" "$OUTFILE" \
 && cat $CMDOUT \
 && ls -la "$OUTFILE" && echo -n "Stop: " && date \
 && echo "Result: success" || echo "Result: failure"

## FIXME: use the initrd and the separate stage1.sh stage2.sh
#    --add-section .initrd="$INITRD"   --change-section-vma .initrd=0x3000000 \
## TODO: add a logo
#    --add-section .splash="splash.bmp" --change-section-vma .splash=0x40000 \
