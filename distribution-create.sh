#!/usr/bin/sh

## This is the distro builder: create the distro dir
# TODO: add a script to create the ISO
# TODO: create a VHDX too (for WSL2)
# TODO: consider creating initrd/ the same way
# FIXME: remove diskimage/ when can be done from this script + stage1and2 re integrated

BASEDIR="./distribution"
ASSETSDIR="./downloads"

# wget is the only dependency besides a posix shell
# try to use the default
WGET=$( type -p wget )
[ -z "${WGET}" ] \
 && [ -f ${ASSETSDIR}/wget ] \
 && [ ! -x ${ASSETSDIR}/wget ] \
 && chmod +x ${ASSETSDIR}/wget

# or the one included by default, which should not be removed
# TODO: when using a Makefile, make sure it doesn't get deleted
[ -z "${WGET}" ] \
 && [ -x ${ASSETSDIR}/wget ] \
 && WGET=${ASSETSDIR}/wget

# if there's no executable wget yet, ask to download it
[ ! -x "${WGET}" ] \
 && echo "Can't go on without wget: you need to download it, like from" \
 && echo "	http://cosmo.zip/pub/cosmos/bin/wget" \
 && echo "Place the resulting file in ${ASSETSDIR}/wget or somewherein your path:" \
 && echo "	$PATH" \
 && exit 1

echo "Creating the image in ${BASEDIR} using ${WGET} and ${MKNOD}"

## 0. Start anew
rm -fr ${BASEDIR}
mkdir ./${BASEDIR}

## 1. Create the filesystem tree

# create the directories
for d in abc busybox busybox/scripts dev dev/pts etc initrd opt proc run sys tmp usr ; do
 mkdir ${BASEDIR}/$d
done

## 2. Fill in the filesystem tree

## 2.1. Fill in the root with the dot files from skel
# the trailing . after dots/ is important to avoid creating dots/ in target
cp -adr skel/dots/. ${BASEDIR}

## 2.2. Fill in abc/ with enough to prepare A Baremetal Cosmopolinux

cp -adr baremetal/*sh baremetal/cmdline* baremetal/README* baremetal/os-release baremetal/linuxx64.efi.stub ${BASEDIR}/abc

## 2.3. Populate busybox/ (until it can be APE'ified)
[ -f ${ASSETSDIR}/busybox ] \
 || ${WGET} https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox -O ${ASSETSDIR}/busybox
cp ${ASSETSDIR}/busybox ${BASEDIR}/busybox/busybox
chmod 755 ${BASEDIR}/busybox/busybox 
BB_TOOLS=$( ${BASEDIR}/busybox/busybox -l )
# Add symlinks for the tools
for t in $BB_TOOLS ; do
 ln -sf ./busybox ${BASEDIR}/busybox/$t
done
# Add scripts due to NTFS3 symlink issues in chroot
# TODO: try to do without, or fix upstream?
for t in $BB_TOOLS ; do
 echo "/busybox/busybox $t \$*" > ${BASEDIR}/busybox/scripts/$t
 chmod 755 ${BASEDIR}/busybox/scripts/$t
done

## 2.4. Populate a minimal dev/
mknod -m 622 ${BASEDIR}/dev/console c 5 1
mknod -m 666 ${BASEDIR}/dev/null c 1 3
mknod -m 666 ${BASEDIR}/dev/zero c 1 5
mknod -m 666 ${BASEDIR}/dev/ptmx c 5 2
mknod -m 666 ${BASEDIR}/dev/tty c 5 0
mknod -m 444 ${BASEDIR}/dev/random c 1 8
mknod -m 444 ${BASEDIR}/dev/urandom c 1 9
mknod -m 622 ${BASEDIR}/dev/kmsg c 1 11
mknod -m 622 ${BASEDIR}/dev/ttyS0 c 4 64

## 2.5. Fill in etc/ from skel
echo cosmopolinux > ${BASEDIR}/etc/hostname
cat skel/etc/udhcpd.conf > ${BASEDIR}/etc/udhcpd.conf
cat skel/etc/resolv.conf > ${BASEDIR}/etc/resolv.conf

## 2.6. Fill in usr/bin/

# Only download the assets if needed (ex: make mrproper)
[ -f ${ASSETSDIR}/cosmos.zip ] \
 || ${WGET} https://cosmo.zip/pub/cosmos/zip/cosmos.zip -O ${ASSETSDIR}/cosmos.zip
[ -f ${ASSETSDIR}/unzip ] \
 || ${WGET} --no-parent -r https://cosmo.zip/pub/cosmos/bin/unzip -O ${ASSETSDIR}/unzip
[ -x ${ASSETSDIR}/unzip ] \
 || chmod +x ${ASSETSDIR}/unzip

${ASSETSDIR}/unzip ${ASSETSDIR}/cosmos.zip -d ${BASEDIR}/usr

# FIXME: may need to extras like box, perl and fzy until added to superconfigure
for e in fzy perl sbase-box; do
 cp skel/$e.com ${BASEDIR}/usr/bin
done

# FIXME: compared to https://cosmo.zip/pub/cosmos/bin/
# missing the following in https://cosmo.zip/pub/cosmos/zip/cosmos.zip
for m in ape-aarch64.elf ape-arm64.elf ape-x86_64.elf ape-x86_64.macho assimilate-aarch64.elf assimilate-x86_64.elf assimilate-x86_64.macho clang-format cpuid curl dash hello links llama mktemper rsync wget ; do
 [ -f ${BASEDIR}/usr/bin/$m ] \
  || ${WGET} https://cosmo.zip/pub/cosmos/bin/$m -O ${BASEDIR}/usr/bin/$m
done

# make usr/bin/* executable
chmod +x ${BASEDIR}/usr/bin/*

## 2.7. Fill in opt/ with cosmocc and git

[ -f ${ASSETSDIR}/cosmocc.zip ] \
 || ${WGET} https://cosmo.zip/pub/cosmos/zip/cosmocc.zip -O ${ASSETSDIR}/cosmocc.zip

${ASSETSDIR}/unzip ${ASSETSDIR}/cosmocc.zip -d ${BASEDIR}/opt/cosmocc

[ -f ${ASSETSDIR}/git.zip ] \
 || ${WGET} https://cosmo.zip/pub/cosmos/zip/git.zip -O ${ASSETSDIR}/git.zip

${ASSETSDIR}/unzip ${ASSETSDIR}/cosmocc.zip -d ${BASEDIR}/opt/git
