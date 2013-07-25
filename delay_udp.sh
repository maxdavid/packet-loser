#!/bin/bash

#
# Delay every nth packet output by a given multiple of 10ms
#
# usage: ./delay_udp.sh <delay in ms> <n delay>
#   $1 = number of milliseconds to delay packet
#   $2 = n, as in 'every nth packet is delayed'
#

DST_IP=129.170.213.70/32
OUT_ETH=eth0
CIPHER=aes256cbc

# Number of milliseconds to delay every nth packet
DELAY_MS=$1
DELAY_MS+=ms

NTH_DELAY=$2
WHICH_IN_N=$(expr $2 - 1)

# ???
MARK=777

# Name of directory to store testing data
TEST_DIR=openvpn_delay$DELAY_MS
TEST_DIR+=_every$NTH_DELAY
TEST_DIR+=_$CIPHER


# delete old rules (this clears only the mangle table)
iptables -t mangle -F

# This rule marks outgoing packets for delay. Routing queues will
#   put packets in the delaying queue if they match the mark.
iptables -t mangle -A POSTROUTING -d $DST_IP -o $OUT_ETH -m statistic --mode nth --every $NTH_DELAY --packet $WHICH_IN_N -j MARK --set-mark $MARK

# delete queue tree on outgoing interface
tc qdisc  del dev $OUT_ETH root

# set up queues on outgoing interface
tc qdisc  add dev $OUT_ETH root handle 1: prio
tc qdisc  add dev $OUT_ETH parent 1:3 handle 30: netem delay $DELAY_MS
tc filter add dev $OUT_ETH protocol ip parent 1:0 handle $MARK fw flowid 1:3

mkdir $TEST_DIR
cd $TEST_DIR
tshark -i any -w $TEST_DIR -b filesize:1024

echo
echo "Resetting iptables..."
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F
iptables -X

echo Done.
exit 0
