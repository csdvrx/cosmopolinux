#!/usr/bin/sh
# can also support lz4/zstd depending on CONFIG_RD_ZSTD=y/CONFIG_RD_LZ4=y
# TODO: consider creating initrd-add-bash to add bash and its .bashrc .bash_profile .inputrc .sqliterc_bash
cd initrd \
 && find . |grep -v ^./extra | cpio -H newc -o | gzip > ../initrd.cpio.gz \
 && cd ..
