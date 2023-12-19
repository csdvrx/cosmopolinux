#!/usr/bin/sh
# Copyright (C) 2023, csdvrx, MIT licensed

# Cosmopolinux: uses a linux kernel around cosmopolitan binaries, with as little bloat as possible
#
# Can run baremetal, or with qemu
# cf https://wiki.archlinux.org/title/QEMU
#    https://qemu.weilnetz.de/w32/2011/2011-02-10/qemu-doc.html
#    https://fishilico.github.io/generic-config/sysadmin/qemu.html
#
# Goals for the cosmopolinux qemu script: emulation with as much as possible KVM paravitualization to:
#  - demonstrate the concepts for cosmopolinux without having to run it baremetal
#  - help development of cosmopolitan by providing a linux distribution of the cosmo binaries
#  - get the most performance of cosmopolitan binaries when replacing docker (guest)
#  - study how cosmopolinux could use kernels for replacing ESXi (host)

### Parameters
QEMU=$(type -p qemu-system-x86_64)
QEMU_KERNEL="./kernel.bzImage"
QEMU_INITRD="./initrd.cpio.gz"
VNC="gvncviewer"
HOST_TAP="172.20.20.2/24"
#HOST_TAP="172.20.20.2/8"
# Hardcoded
# Or randomly assigned
[ -n $RANDOM ] \
&& HOST_TAP_DEV="qemu-tap$RANDOM" \
|| HOST_TAP_DEV="tap0"
# override
#HOST_TAP_DEV="tap0"
# Save what's run to qemu.sh for debug
#QEMU_SH=1

[ -f $QEMU ] && [ -f $QEMU_KERNEL ] && [ -f $QEMU_INITRD ] \
 || echo "missing key file from $QEMU $QEMU_KERNEL $QEMU_INITRD"

#### Base
LIN=" -cpu host"
# Might also be able to use a windows kernel: should it then be called cosmopowindowspe?
# cf https://wiki.archlinux.org/title/Windows_PE
# If running Windows as guest, add Hyper-V enlightenments
#WIN=" -cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time"
BASE=" -enable-kvm $LIN -machine type=pc,accel=kvm -rtc base=localtime -action reboot=shutdown"
#"-no-reboot"
#
# kvm requires:
# intel: kvm_intel + cpu support (vmx):
# amd: kvm_amd + cpu support (svm)
echo $BASE|grep -q enable-kvm \
 && grep -q -E --color=auto 'vmx|svm|0xc0f' /proc/cpuinfo \
 || echo "no kvm found, check the bios settings"
#  grep Y /sys/module/kvm_intel/parameters/nested

#### Memory
#MEM=" -m1G "
# if hugetlbfs on /dev/hugepages, and each 2M
# TODO: but 1G pages too, check if why not use them:
# HugeTLB: registered 1.00 GiB page size, pre-allocated 0 pages
# WARNING: reports of bug when compacting memory with zfs:
# cf https://github.com/openzfs/zfs/issues/15140
sudo echo 550 > /proc/sys/vm/nr_hugepages
# can then use 1G as:
MEM=" -m 1024 -mem-path /dev/hugepages"
# TODO: consider -device virtio-balloon to be able to reclaim memory from guests

# Kernel Samepage Merging helps reduce RAM for multiple VM (ksmctl and ksmtuned) but costs CPU time
#echo 1 > /sys/kernel/mm/ksm/run


#### CPU
# if using for CPU intensive work, reserve some cores matching the cpu topology of `lscpu -e`
# for example, if using isolcpus=4-7 on the host, then start qemu with:
#CPUPINNING_PREFIX="chrt -r 1 taskset -c 4-7 "
#CPU=" -smp 3"
CPU=" -cpu host -smp 1"

# TODO: CPU pinning + PCI passthrough for high performance cosmopolinux guest apps
# could also give the network devices to the KVM running the app, with VFIO (WIP)
# cf https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Setting_up_IOMMU
# TODO: consider alternative scenario: baremetal cosmopolinux host, virtualize the rest
# DRM_VIRTIO_GPU: could be used for headless GPU passthrough (GVTd): cosmopolinux host + win|ubuntu
# TODO: -device intel-iommu etc

#### Firmware
# QEMU boots a BIOS firmware by default:
# loads a 512 byte flat binary blob from the MBR of the boot device
# into memory at physical address 7C00s then jumps to it.
#
# FIXME: UEFI depends on OVMF to provide the correct firmware with
# -smbios type=0,uefi=on -bios /usr/share/ovmf/OVMF.fd
# rough equivalent while keeping efivars separate from OVMF:

#UEFI=" -device vfio-pci,host=01:00.0,multifunction=on \
# -device vfio-pci,host=01:00.1 \
# -drive if=pflash,format=raw,readonly,file=OVMF_CODE_only.fd
# drive if=pflash,format=raw,file=OVMF_VARS_only.fd"

# Options:
# -change from 0 disk image (ntfs3)
#   - to 2 partitions in 1 disk image?
#   (can't dd the ntfs3 image to a partition, but rare usecase)
#   - to 2 disk images?
#   (risk to dd the efi image to the efi partition)
#   - to 2 whatever-is-best-native assembled into 1 by a script just for qemu
# - or keep the ntfs3 image but
#   - add to the MBR for loadlin
#   - add an EFI payload in a well known path but non standard path
#   like \BOOT\EFI\BOOX64.EFI chainloaded by rufus from regular EFI
#    => seems like the best option but needs:
#      - objcopy to create the UKI
#      - efibootmgr to alter the settings

#### Interaction
#VIEW=" -vga virtio -display gtk,full-screen=off,gl=off,grab-on-hover=on"
# ideally would have multiple ways to view the display, but qemu only supports one console per console driver
# because drivers are shared between the same type, so for multiple need different types: like serial+video
#VIEW=" -display gtk,full-screen=on,gl=on,grab-on-hover=on"
# better redirect the display to VNC: can get it with `gvncviewer ::1:5900`
VIEW=" -display vnc=:0" # :0 means port 5900
# TODO: check if it be possible to do multihead in mirror mode with qxl, one sent to gtk, the other to vnc
# other options:
#VIEW=" -display curses"
#VIEW=" -nographic" # mostly changes default -serial vc to -serial stdio, without imposing -vga none

# better mouse integration by pretending to be a tablet to avoid having to grab the mouse from the host when clicking
MICE=" -usb -usbdevice tablet"

#### Monitor: over both network and serial
# monitor control: can be used for hotplugging devices and screendump
# cf http://nairobi-embedded.org/qemu_monitor_console.html
MONC=" -monitor telnet:127.0.0.1:6999,server,nowait"

#### Console
# stdin and stdout of qemu tty are sent to /dev/hvc0 since CONFIG_VIRTIO_CONSOLE=y
TSIO=" -chardev stdio,id=stdinout -device virtio-serial -device virtconsole,chardev=stdinout"

# Request that hvc0 as a kernel console, also request a serial port console as defined below 
# for boot logs get early printk support aim for a little slower than the usual 115200 (safer)
# cf https://wiki.qemu.org/Features/ChardevFlowControl
# can check /sys/class/tty/console/active to know which requests were granted
KCONSOLE="console=hvc0 console=ttyS0,38400n8 earlyprintk=serial,ttyS0,38400n8 console=tty quiet loglevel=6 highres=off"
#
# For kernel debug over a remote connection, try kgdboc=ttyS0,38400
#  needs CONFIG_KGDB=y and CONFIG_KGDB_SERIAL_CONSOLE=y
# Or toggle:
#  echo ttyS0 > /sys/modules/kgbdoc/parameters/kgbdoc
#  echo g > /proc/sysrq-trigger
# If qemu debug is also needed:
#QEMUDEBUG=" -debugcon telnet:127.0.0.1:7001,server,nowait -gdb tcp:127.0.0.1:7004"

#### Serial ports
# guest serial port /dev/ttyS0 exposed by telnet, for easier connection
TTYS0=" -serial telnet:localhost:7000,server,nowait,nodelay"
#TTYS0=" -chardev socket,id=s1,port=7000,host=localhost,server=on,wait=off,telnet=on,nodelay=on"

# guest serial port /dev/ttyS1 was used for a text console
#TTYS1=" -serial stdio"
# same but can send ctrl-c to guest by multiplexing the serial port and qemu monitor into stdio
#TTYS1=" -serial mon:stdio"
# Now that stdio is redirected to hvc0, ttyS0 can be used for a pty exported as /dev/pts/X
TTYS1=" -serial pty"
# qemu sequentially supports up to 4 ttys as-is, we only need 2 here
# todo: could have 2 more: a fifo/name pipe, and a vc:80Cx24C
TTY="$TTYS0 $TTYS1 $TTYS2 $TTYS3"
# can get 4 more: -serial XX is shorthand for -chardev type XX on host redirected to guest serial port
# can assign 4x mode (ttyS4..S7) if -device pci-serial-4x,chardev1=s0,chardev2=s1,chardev3=s2
# but risk off-by-one or two of the terminal mappings if wrong backend (pci-serial=empty, -2x, -4x?)

#### Network
# QEMU needs in the kernel
# -> Device Drivers
#  -> Network device support (NETDEVICES [=y])
#   -> Network core driver support (NET_CORE [=y])
#    -> Virtio network driver (VIRTIO_NET [=y])
# Selects: NET_FAILOVER [=y]

# first get 2 random mac address to support bridging multiple vm like -net nic,macaddr=52:54:XX:XX:XX:XX
# because otherwise always the same sequence: 
# eth0 (guest:virtio, host:tap0) is ..:12:34:56
# eth1 (guest:e1000,   host:nat) is ..:12:34:57

# WONTFIX: will have 52:54:01 for the 1st mac + ensure it's never 00:12:34:56
# can then disambiguate the 2 interfaces regardless of the host enumeration order

# Check if $RANDOM is defined, if so use it
[ -n "$RANDOM" ] \
 && macaddr0=$(printf "52:54:00:%02x:%02x:%02x" \
   $(( $RANDOM & 0xff )) $(( $RANDOM & 0xff)) $(( $RANDOM & 0xff )) \
 ) \
 && macaddr1=$(printf "52:54:01:%02x:%02x:%02x" \
   $(( $RANDOM & 0xff )) $(( $RANDOM & 0xff)) $(( $RANDOM & 0xff )) \
 ) \
 && macaddr2=$(printf "52:54:10:%02x:%02x:%02x" \
   $(( $RANDOM & 0xff )) $(( $RANDOM & 0xff)) $(( $RANDOM & 0xff )) \
 )

# If the macs couldn't be randomized, assign in a deterministic pattern
[ -z "$macaddr0" ] && macaddr0="52:54:00:12:34:56"
[ -z "$macaddr1" ] && macaddr1="52:54:01:12:34:57"
[ -z "$macaddr2" ] && macaddr2="52:54:10:12:34:58"

# Then use the new way with netdev: accelerated, without hub
# cf https://www.qemu.org/2018/05/31/nic-parameter/
# and with scripts for the host (if not desired use script=no)
# NB: using -EOF means the lines are prefixed with 1 tab, but the closing EOF mustn't be
# if no variables are desired, either escape their $ or use -'EOF'
cat <<-EOF > ./host-up-$HOST_TAP_DEV.sh
	#!/bin/sh
	ip link set dev $HOST_TAP_DEV up
	ip addr add $HOST_TAP dev $HOST_TAP_DEV
	exit 0
EOF
cat <<-EOF > ./host-down-$HOST_TAP_DEV.sh
	#!/bin/sh
	ip addr del $HOST_TAP dev $HOST_TAP_DEV
	ip link set dev $HOST_TAP_DEV down
	exit 0
EOF
# Both scripts will have to be removed on exit
chmod 755 ./host-up-$HOST_TAP_DEV.sh ./host-down-$HOST_TAP_DEV.sh

# WARNING: the guest will always enumerate the virtio tap first (so eth0)
# the slow init natted netdev user e1000 will be enumerated last (so eth1)
# regardless of the other or the use of script=no
# => must use mac addresses tricks to determine who is who
#-netdev tap,ifname=$HOST_TAP_DEV,script=./host-up-$HOST_TAP_DEV.sh,downscript=./host-down-$HOST_TAP_DEV.sh,id=n2 -device virtio-net,netdev=n2,mac="$macaddr2" \
# Make 3 interfaces:
#  - first a e1000 or rtl8139 that responds to DHCP
#  - then a virtio tap with static IP
#-netdev user,restrict=off,hostname=cosmopolinux,id=n1 -device e1000,netdev=n1,mac="$macaddr1" \
#-netdev tap,ifname=$HOST_TAP_DEV,script=no,downscript=no,id=n2 -device virtio-net,netdev=n2,mac="$macaddr2" \
# WARNING: the above is too slow, use just one dev
NET=" \
-netdev user,restrict=off,hostname=cosmopolinux,id=n0 -device virtio-net,netdev=n0,mac="$macaddr0" \
 " 
# - on nat can also isolate from the host with user,restrict=on
# user is for slirp user-mode-networking: vm gets ip, and access to host network through IP masquerading
# will use a built-in dhcp server to provide ip=10.0.2.15, gw=10.0.0.2, dns=10.0.0.3 (optional smb=10.0.0.4)
# only provides internet connectivity to the outside world: vms can't talk to eachother
# TODO: consider moving from slirp to paast for security
# cf http://blog.vmsplice.net/2021/10/a-new-approach-to-usermode-networking.html
# could be faster too
# cf https://lore.kernel.org/qemu-devel/20220919232441.661eda8d@elisabeth/

# - on tap can use vhost=on option for MSIX in-kernel acceleration

# old way with 2 separate hubs, and no script (otherwise defaults to /etc/qemu-ifup)
#NET=" -net nic,model=e1000,vlan=0 -net user,vlan=0 -net nic,model=virtio,vlan=1 -net tap,ifname=tap0,script=no,downscript=no,vlan=1"

# TODO: netdev user can simulate TFTP and SMB:
# -netdev user,id=n0,tftp=xxx,bootfile=yyy
# -netdev user,id=n0,smb=dir,smbserver=addr

# WARNING: ping: IPv4 ICMP only and if not root will not work without allowing unpriv ping to qemu user gid
# ICMPv6 will not work at all, not implemented yet
# cf https://lwn.net/Articles/422330/
# default is root only:
sysctl -w net.ipv4.ping_group_range='1 0'
# work around: can allow all GIDs
#sysctl -w net.ipv4.ping_group_range='0 2147483647'

# Can have port forwarding for internet connectivity from the outside to the guest:
# user,hostfwd= for TCP and UDP connections ; can also have guestfwd
# TODO: when ttyd is ready, study how to redirect 127.127.127.127 by port forwarding like hostfwd=tcp::8080-:80

#### Storage
# QEMU needs the virtio block driver in the kernel`
# -> Device Drivers
#  -> Block devices (BLK_DEV [=y])
#   -> Virtio block driver (VIRTIO_BLK [=y])
# Selects: SG_POOL [=y]

# TODO: examine and compare+benchmark other interesting options
# SCSI_VIRTIO: for usb-storage and SATA devices: supports discard/trim
# old
#HDA=" -hda /dev/sdb"
# slow
#SSD=" -drive if=ide,file=/dev/sdb,index=0,format=raw" 
# faster
#SSD=" -drive if=virtio,file=/dev/sdc1,cache=none"
# for test install iso, could use "-boot order=d,c" or "-boot menu=on"
#ISO=" -drive media=cdrom,file=/isore/isos/ubuntu22.iso -boot d"
# actual NTFS partition
#NTFSPART="/dev/nvme0n1p3"
# NTFS image created with ntfs-create.sh
# qemu will acquire a open file descriptor (OFD) locks on each image
# if opens the disk image in exclusive mode and fails to get OFD, will err (ex: if used twice)
# solution is --force-share or file.locking=off
NTFS=cosmopolinux.ntfs3
# partition + file for tests
#BLK=" -drive if=virtio,file=$NTFSPART,format=raw,cache.direct=on,aio=native,media=disk -boot c \
# -drive if=virtio,file=$NTFS,format=raw,cache.direct=on,aio=native,media=disk"
# just the image, with the modern virtio for better performance
BLK=" -drive if=virtio,file=$NTFS,format=raw,cache.direct=on,aio=native,media=disk -boot c"
# TODO: find the difference with to -drive if=none,file=XXX,id=virtio-disk0,format=raw,cache=none,aio=native -device virtio-blk-pci,scsi=off,drive=virtio-disk0,id=disk0 \
# WONTFIX: the BLK like above works as /dev/vda
# but with 4kn ntfs3 actual partition complains about the sector size discrepancy
# virtio_blk virtio1: [vda] 18874368 512-byte logical blocks (9.66 GB/9.00 GiB)
# ntfs3: vda: Different NTFS' sector size (4096) and media sector size (512)
# VFS: Mounted root (ntfs3 filesystem) readonly on device 253:0.
# may need extra options to avoid assuming 512 and be 4kn, and there're options for that:
#  sectorsize=<sector size>/<physical sector size> or sectorsize=<sector size> default to 512/512
# but problem: format=raw doesn't understand sectorsize

# for the storage drive chose one of the above $HDA $SSD $ISO $BLK
STO="$BLK"

# but refuse to use the nvme if selected and can't unmount it (risk corruption)
echo $STO |grep -q $NTFS && umount -f $NTFS
echo $STO |grep -q $NTFS && mount |grep $NTFS && echo "cant unmount blk physical partition $NTFS" && exit 1

#### Hosts devices to the guest
# Can pass physical usb devices from the host to the guest using either
# EHCI (USB 2) 
#EHCI=" -device usb-ehci,id=ehci"
# XHCI (USB 1.1 USB 2 USB 3)
#XHCI=" -device qemu-xhci,id=xhci"
# cf https://www.qemu.org/docs/master/system/devices/usb.html
#USB=" $XHCI -usbdevice host:0abc:00ef"

# main difference between qemu and baremetal root=/dev/vda console=/dev/hvc0 vs root=/dev/nvme0n1p3
#KROOT="ro root=/dev/vda rootfstype=ntfs3"
KROOT="rw root=/dev/vda rootfstype=ntfs3 rootflags=rw crashkernel=256M sysrq_always_enabled"
# TODO: for kexec, experiment with other fun options like crashkernel=256M sysrq_always_enabled in stage 2

# For development, proceed in steps
# 1: check there's an output on a gtk display not using any console as /dev may be an issue
#KINIT="init=/chroot/busybox/ash noinitrd"
# Even if the init works, with rw sometimes need fsck.ntfs (or only clear dirty bit: ntfsfix -d)
# 2: use an initrd (also as a disk image above): test it with rdinit
#KINIT="rdinit=/chroot/busybox/ash"
# 3: use the stage 1 + stage 2 chain:
# rdinit stage1.sh calls initrd chroot stage2.sh calls partition stage3.sh
KINIT="rdinit=/stage1.sh"
# Can also use the combined stage1 and stage2 from the NTFS partition without initrd
#KINIT="init=/chroot/stage1and2.sh noinitrd"
# 4: without busybox: non assimilated cosmo binaries need a /.ape loader in the root filesystem
# meaning either it's put there already, or the root fs is read write and has /bin/mkdir
# wget -O /usr/bin/ape https://cosmo.zip/pub/cosmos/bin/ape-$(uname -m).elf

# for mounting the root: cf kernel/Documentation/admin-guide/kernel-parameters.txt
# rdev: historically hardcoded the major and minor in the kernel
# root: next, cmdline argument passed the device path but /dev not mounted so kernel used hardcoded major/minors
# initrd: then, compressed filesystem to mount the root device to /initrd and pivot_root to switch / and /initrd
# initramfs: now, about the same yet not a filesystem but a cpio archive extracted to a tmpfs, and switch_root instead
# both initrd and initramfs a default rdinit=/init, but initramfs switch_root does a chroot then runs /sbin/init 
# also can disable with noinitrd
# For initrd debug, init=/bin/sh : initramfs equivalent is rdinit=/bin/sh
# may alsouse -strace initcall_debug and noinitd to discard whatever is loaded

# Assemble the options
OPTS="$MEM $CPU $NET $TTY $STO"
#$USB

echo "Can manage qemu with the monitor:
	telnet localhost 6999"

# screen baud_rate,cs8|cs7,ixon|-ixon,ixoff|-ixoff,istrip|-istrip
# here 38400, 8 bit, software flow control enabled, keep the received 8th bit
echo "Comopolinux has 2 consoles on top of stdin/stdout + VNC.
Therefore, you can also connect with either:
	telnet localhost 7000				(ttyS0 getty bash)
	picocom -b 38400 /dev/pts/X			(see below char device is redirected to)
	screen /dev/pts/X 38400,cs8,ixon,-istrip	(gnu screen is a more common alternative)
	gvncviewer ::1:5900				(graphical display)"

# Assemble the kernel cmdline:
KCMDLINE="$KCONSOLE $KROOT $KINIT"

echo "Running:
	$CPUPINNING_PREFIX \"$QEMU\"
	-kernel \"$QEMU_KERNEL\"
	-initrd \"$QEMU_INITRD\"
	-append \"$KCMDLINE\" 
	$BASE $VIEW $MICE $TSIO $MONC $OPTS"

# WARNING: don't use a echo | sh otherwise can't send from the host tty stdin to the guest ttyS0

## save that to a file for debugging
# can save the script like
[ -n $QEMU_SH ] && \
echo "$CPUPINNING_PREFIX \"$QEMU\" \\\
 -kernel \"$QEMU_KERNEL\" \\\
 -initrd \"$QEMU_INITRD\" \\\
 -append \"$KCMDLINE\" $BASE $VIEW $MICE $TSIO $MONC $OPTS" > ./qemu.sh

echo $VIEW | grep -q gtk \
 && [ -n $SUDO_USER ] \
 && echo "WARNING: if using sudo, on xorg, need 'xhost +'" \
 && sudo -u $SUDO_USER /bin/sh -c "xhost +"

# to automatically start VNC using gvncview 
#sudo -u $SUDO_USER /bin/sh -c "sleep 2 && $VNC ::1:5900 &" &

$CPUPINNING_PREFIX "$QEMU" \
  -kernel "$QEMU_KERNEL" \
  -initrd "$QEMU_INITRD" \
  -append "$KCMDLINE" \
  $BASE $VIEW $MICE $TSIO $MONC $OPTS \

echo $? |grep ^0$ \
  && echo "Exited succesfully" \
  && [ -n $QEMU_SH ] \
  && [ -f ./qemu.sh ] \
  && echo "Clearing ./qemu.sh" \
  && rm -fr ./qemu.sh

echo "Cleaning up files ./host-up-$HOST_TAP_DEV.sh ./host-down-$HOST_TAP_DEV.sh"
rm ./host-up-$HOST_TAP_DEV.sh
rm ./host-down-$HOST_TAP_DEV.sh

echo "On failure, run gev.sh"
