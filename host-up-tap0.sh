#!/usr/bin/sh
ip link set dev tap0 up
ip addr add 172.20.20.2/24 dev tap0
exit 0
