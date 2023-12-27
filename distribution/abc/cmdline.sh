#!/bin/sh
## Copyright (C) 2023, csdvrx, MIT licensed

### Root devices
## Define the root device as read-write to save a remount
echo -n " rw"
# Can use either the partition number (first is nvme0n1p1)
echo -n " root=/dev/nvme0n1p9"
# Or the UUID from blkid
#echo -n " root=UUID=aaa-bbb-ccc-ddd"
# For now, only ntfs3 is tested as the rootfs
echo -n " rootfstype=ntfs3"
# FIXME: move the old merged stage1+2 into stage1 and stage2
echo -n " init=/chroot/stage1and2.sh"

### Kernel debug
## During devel, sysreq may be needed
echo -n " sysrq_always_enabled"
## Keep 1M of long for use with devkmsg
#echo -n " log_buf_len=1M printk.devkmsg=on"
## Show what's written to /dev/kmsg
echo -n " loglevel=6"
## Save kdump for kernel debug, https://wiki.archlinux.org/title/Kdump
echo -n " crashkernel=256M"

### ACPI
## Pretending to be windows is always a good idea to get sane defaults
# 2020= Windows 10 2004, 2021= Windows 11, 2022=Windows 11 22H2
# Old style
#echo " acpi_osi=! \"acpi_osi=Windows 2021\""
# New style
echo -n " acpi_osi=!Windows2021"
## If both ACPI S3 and S01x are supported, can prefer S3:
#echo -n " mem_sleep_default=deep"
## ACPI default for PCI devices
# Waste power:
#echo -n " pcie_aspm.policy=performance"
# Save power as much as possible: (risk firmware bugs)
#echo -n " pcie_aspm.policy=powersupersave"
# Intermediary:
echo -n " pcie_aspm.policy=powersave"
# if some devices refuse, can force whatever with:
#echo -n " pcie_aspm=force"

### PCI
# Problem with the SN740: seems like a thermal protection, not reported due to lack of AER advertisement in _OSC
# acpi PNP0A08:00: _OSC: platform does not support [AER]
#  can force that with "pcie_ports=native" 
echo -n " pcie_ports=native"
# using pci=nommconf breaks that

### NVMe
## Limit NVME queues for nocbs: bad for IOPS performance, good for powersaving (with irqaffinity)
echo -n " nvme.poll_queues=1 nvme.write_queues=1"
## Attempted workaround the disconnection problems on the SN740 with power settings
# 0 +     5.40W    5.40W       -    0  0  0  0        0       0
# 1 +     3.50W    3.00W       -    0  0  0  0        0       0
# 2 +     2.40W    2.00W       -    0  0  0  0        0       0
# 3 -   0.0150W       -        -    3  3  3  3     1500    2500
# 4 -   0.0050W       -        -    4  4  4  4    10000    6000
# 5 -   0.0033W       -        -    5  5  5  5   176000   25000
# 
# Initially seemed to work:
#echo -n " pcie_aspm=off pci=nocrs acpi_enforce_resources=lax nvme.noacpi=on"
# Enabling ASPM + relaxing latency requirements to include PS3 didn't work
#echo -n " nvme_core.force_apst=on nvme_core.default_ps_max_latency_us=5500"
# Next tried disabling APST: would have pinpointed to thermal issues
# Didn't work, so back to generic reasonable defaults:
echo -n " acpi_enforce_resources=lax nvme_core.force_apst=on nvme_core.default_ps_max_latency_us=7000"

### Manual core allocation for qemu performance and power savings
## Enable iotop measurements: allocate and track task_delay_info struct
# this means iotop should be changed to use taskstats, cf https://superuser.com/questions/610581/iotop-complains-config-task-delay-acct-not-enabled-in-kernel-only-for-specific
# because kernel.task_delayacct has effects on system performance, not by default
#echo -n " delayacct"
## Try to use cores differently, example on little.big Alder Lake P
# coretype reports:
#P CORES: 0..7
#E Cores: 8..19
## Here:
# - Leave efficiency cores 8..19 as-is (on them, nohz_full is not ideal and consumes power)
# - Use power core 0 as normal
# - Put all the other power cores 1-7 but 4 in NOHZ_FULL
# - Put all IRQ and callbacks on power core cpu 4: performance + a race to sleep
# NB: can use both cores one of the avx512-less efficiency core.id 8 with irqaffinity=4-5
#echo -n " tsx_async_abort=full cpu0_hotplug nohz_full=1-3,5-7 nr_running=1 rcu_nocbs=0-3,6-7 irqaffinity=4-5 nmi_watchdog=0 nosoftlockup"
# Can see which cores are on core.id 8 with:
#cat /proc/cpuinfo  |egrep "physical|core.id|cache.size|processor" |grep -E "core.id|processor"
#echo -n " tsx_async_abort=full cpu0_hotplug nohz_full=1-3,5-7 rcu_nocbs=0-3,5-7 irqaffinity=4 nmi_watchdog=0 nosoftlockup "
## FIXME: iwlwifi still puts interrupts on every core, cf `cat /proc/interrupts`

### Video with Intel GPUs
## Try a flicker free boot
#echo -n " i915.fastboot=1"
echo -n " i915.fastboot=1 keep_bootcon"
# TODO: also try to remove the logo with video=efifb:nobgrt or bgrt_disable or both?
#echo -n " bgrt_disable"
## Extra power savings + try to avoid the first blink
# don't use i915.modeset=0 + nomodeset: blank screen, need at least one
#echo -n " nomodeset i915.modeset=1 drm_kms_helper.poll=0"
# Reasonable defaults:
echo -n " i915.enable_psr2_sel_fetch=1 i915.enable_fbc=1 i915.enable_psr=1"
## Fullblock cursor
#echo -n " vt.global_cursor_default=8 fbcon.cursor_blink=0"
#cf https://www.kernel.org/doc/html/latest/admin-guide/vga-softcursor.html
# blink could be tweaked during boot with /sys/devices/virtual/graphics/fbcon/cursor_blink

### WIFI
## Save power on iwlwifi
#echo -n " iwlwifi.power_save=1 iwlwifi.power_level=2"
echo -n " iwlwifi.power_save=1 iwlwifi.power_level=5 iwlwifi.d0i3_disable=0 iwlwifi.uapsd_disable=0"
# either one or the other, check which with `dmesg |grep iwl.vm`
#echo -n " iwldvm.force_cam=0"
# 1 is conservative, but up to 4 works fine, something might cause delays at montroig but 4 didn't help
echo -n " iwlmvm.power:scheme=3"
## Hint in case it can save negociation time
#echo -n " cfg80211.ieee80211_regdom=US"

# EOF
echo
