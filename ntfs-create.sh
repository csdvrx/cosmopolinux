#!/usr/bin/sh
SIZE="2G"
# Don't add a final / to the source, rsync will do it
SOURCE="./distribution"
TARGET="cosmopolinux.ntfs3"
BLOCKDEVNUM=4 # to avoid loop0 or nbd0 being already used
MOUNTPOINT="/ntfs"
# The one directory where cosmopolinux lives in
ONEDIR="/chroot"
RSYNCFLAGS="-HhPpAaXxWvtUU"
# options used above:
#
# --hard-links, -H         preserve hard links
# --human-readable, -h     output numbers in a human-readable format
# -P                       same as --partial --progress
# --progress               show progress during transfer
# --partial                keep partially transferred files
# --perms, -p              preserve permissions
# --acls, -A               preserve ACLs (implies --perms)
# --archive, -a            archive mode is -rlptgoD (no -A,-X,-U,-N,-H)
# --xattrs, -X             preserve extended attributes
# --one-file-system, -x    dont cross filesystem boundaries
# --whole-file, -W         copy files whole (w/o delta-xfer algorithm)
# --verbose, -v            increase verbosity
# --times, -t              preserve modification times
# --atimes, -U             preserve access (use) times
#                          (If repeated, it also sets the --open-noatime)
# --open-noatime           avoid changing the atime on opened files
#
# not used as not always supported:
# --crtimes, -N            preserve create times (newness)

# Check we have everything
[ -f ${TARGET} ] \
 && [ "$1" == "-f" ] \
 && rm ${TARGET} \

[ -f ${TARGET} ] \
 && echo "Refusing to overwrite the existing ${TARGET} unless given the option -f" \
 && exit 1

[ -d ${MOUNTPOINT} ] \
 || sudo mkdir ${MOUNTPOINT} \
 || exit 2

# Cheap trick to detect the directory has been filled
[ ! -x ${SOURCE}/usr/bin/rsync ] \
 && echo "First run ./distribution-create.sh" \
 && exit 2

# creating a sparse image could be better than dd and losetup in the future
# but less portable: need to cat /dev/nbd0 to $TARGET to get the ntfs3 anyway
INITIALIZE="qemu-img create -f qcow2 ${TARGET%.ntfs3}.qcow2 ${SIZE}"
MODULE="sudo modprobe nbd"
BLOCKDEV=/dev/nbd${BLOCKDEVNUM}
CREATE="sudo qemu-nbd -c ${BLOCKDEV} ${TARGET}"
CLOSE="sudo qemu-nbd -d ${BLOCKDEV}"

INITIALIZE="dd if=/dev/zero of=${TARGET} bs=${SIZE} count=1"
MODULE="sudo modprobe loop"
BLOCKDEV=/dev/loop${BLOCKDEVNUM}
CREATE="sudo losetup ${BLOCKDEV} ${TARGET}"
CLOSE="sudo losetup -d ${BLOCKDEV}"

# Then format it with either paragon ntfs tool (or ntfs-3g:
#  - paragon mkntfs needs:
#MKNTFSOPTION="-v:Cosmopolinux"
#  - while ntfs3 mktfs needs:
MKNTFSOPTION="-L:Cosmopolinux -Q"
# Get paragon tool from https://d.apkpure.com/b/APK/com.paragon.mounter?version=latest
# then extract mkfs and chkntfs:
# unzip "Paragon UFSD Root Mounter_2.0.4_Apkpure.apk" assets/x86/chkufsd assets/x86/mkntfs -d /tmp
# mv /tmp/assets/x86/mkntfs /usr/local/bin/mkntfs
# mv /tmp/assets/x86/chkufsd /usr/local/bin/chkntfs
# chmod +x /usr/local/bin/mkntfs /usr/local/bin/chkntfs
FORMAT="sudo mkntfs ${MKNTFSOPTION} ${BLOCKDEV}"
MOUNT="sudo mount $BLOCKDEV $MOUNTPOINT"
UMOUNT="umount $MOUNTPOINT"

# create, format mount, rsync and umount, or remove the failed blocdev
${INITIALIZE} 2>/dev/null \
 && ${MODULE} \
 && ${CREATE} \
 && ${FORMAT} \
 && ${MOUNT} \
 && echo \
 && echo -n "rsync ${RSYNCFLAGS} ${SOURCE}/ ${MOUNTPOINT} #" \
 && ${SOURCE}/usr/bin/rsync ${RSYNCFLAGS} ${SOURCE}/ ${MOUNTPOINT}${ONEDIR}

# time is a trick to make sure it's synced, like sync;sync
time sync

# TODO: is it a good idea to trim?
trim ${MOUNTPOINT}

echo
echo "Size once packed"
# show the space used
du -ksh ${MOUNTPOINT}

[ -f ${TARGET} ] \
 && echo \
 && echo "Created ${TARGET} from ${SOURCE} using ${BLOCKDEV}:" \
 && stat -c "%y %s %n" ${TARGET} \

# regardless, try to umount and close the block device
${UMOUNT}
${CLOSE}
