#!/usr/bin/sh
## generate the environment for virtualization (with qemu)
# FIXME: currently only packs initrd, add ntfs-pack.sh iso-pack.sh etc
./fsck.sh && ./initrd-pack.sh && \
 ./stage0-qemu.sh
