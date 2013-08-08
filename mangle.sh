#!/bin/bash
#
# Specify a type of iptables mangling to do for the outgoing interface.
#
# usage:
#   mangle.sh <outgoing_ip> <mangle_type> <n> <additional> 
#     $1 : outgoing IP address to operate on (optional if defined below)
#     $2 : type of mangling to perform. options detailed below.
#     $3 : nth packet (as in, "operate on every nth packet")
#     $4 : additional info for mangle type, see below.
#
# Mangle Types
#   delay - delays every nth packet by the given number of milliseconds. $4 
#           is the number of ms to delay the packet by.
#   drop  - drops every nth packet. no additional info needed.
#   trunc - truncates every nth packet by the given number of bytes. $4 is 
#           the number of bytes to truncate from the packet.
#   reset - (or 'clean') reset the 'mangle' table in iptables. accepts no 
#           additional parameters.
# set -e

SERVER_IP=$1
MANGLE_TYPE=$2
NTH_PACKET=$3
WHICH_IN_N=$(expr $NTH_PACKET - 1) # needed for statistic syntax

if [ -z "$SERVER_IP" ]; then
  echo "Need outgoing IP. Exiting."
  exit 1
elif [ -z "$MANGLE_TYPE" ]; then
  echo "Need mangle type. Exiting."
  exit 1
elif [ $(whoami) != 'root' ]; then
  echo "You should probably run this as root."
  exit 1
fi

OUT_IFACE=eth0   # Interface to operate on


function mangle_delay() {
  DELAY_MS+=ms
  MARK=777  # can be any number

  echo "Setting up iptables to delay every $NTH_PACKET by $DELAY_MS."

  # This rule marks outgoing packets for delay. Routing queues will
  #   put packets in the delaying queue if they match the mark.
  iptables -t mangle -A POSTROUTING -d $SERVER_IP'/32' -o $OUT_IFACE -m statistic --mode nth --every $NTH_PACKET --packet $WHICH_IN_N -j MARK --set-mark $MARK

  # delete queue tree on outgoing interface
  tc qdisc  del dev $OUT_IFACE root

  # set up queues on outgoing interface
  tc qdisc  add dev $OUT_IFACE root handle 1: prio
  tc qdisc  add dev $OUT_IFACE parent 1:3 handle 30: netem delay $DELAY_MS
  tc filter add dev $OUT_IFACE protocol ip parent 1:0 handle $MARK fw flowid 1:3
}

function mangle_trunc() {
  echo "nope." # FIXME
}

function mangle_drop() {
  echo "Setting up iptables to drop every $NTH_PACKET."

  # This rule marks outgoing packets for delay. Routing queues will
  #   put packets in the delaying queue if they match the mark.
  iptables -t mangle -A POSTROUTING -d $SERVER_IP'/32' -o $OUT_IFACE -m statistic --mode nth --every $NTH_PACKET --packet $WHICH_IN_N -j DROP
}

function demangle() {
  echo "Resetting iptables..."
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT
  iptables -F
  iptables -X

  echo "iptables reset."
}



# Main

# delete old rules (this clears only the mangle table)
iptables -t mangle -F
echo

if [ "$MANGLE_TYPE" == "delay" ]; then
  DELAY_MS=$4
  mangle_delay
elif [ "$MANGLE_TYPE" == "trunc" ]; then
  NUM_BYTES=$4
  echo "Truncate not yet supported." && exit 1
elif [ "$MANGLE_TYPE" == "drop" ]; then
  mangle_drop
elif [ "$MANGLE_TYPE" == "reset" ] || [ "$MANGLE_TYPE" == "clean" ]; then
  demangle
else
  echo "Mangle type not recognized."
  exit 1
fi

exit 0
