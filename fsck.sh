#!/usr/bin/sh
umount -f /ntfs
losetup -d /dev/loop7
echo y
losetup /dev/loop7 ./cosmopolinux.ntfs3
/opt/ntfs-paragon/ntfs/chkufsd -fs:ntfs /dev/loop7 -f 
# FIXME: check they are included
#mount /dev/loop7  /ntfs/ ; \
# cp cosmopolinux/dots/.bash_profile cosmopolinux/dots/.bashrc cosmopolinux/dots/.inputrc cosmopolinux/dots/.sqliterc_bash /ntfs
losetup -d /dev/loop7
