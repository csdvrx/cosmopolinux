#!/usr/bin/sh
ip addr del 172.20.20.2/24 dev tap0
ip link set dev tap0 down
exit 0
