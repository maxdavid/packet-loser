#!/bin/bash
#
# Specify a range of delay times, nth delays, and transfer sizes to be tested.
#
# usage:
#   test_range.sh <spec_file> [<destination_ip>]
#     $1 : file path of the spec file
#     $2 : destination IP to operate on (optional if defined here)
# 
# Spec file is made simply. Each line is an individual test, with numbers to 
# specify its parameters (size of file transfer, delay time, and the number 
# between each delay), separated by a space. Like so:
#
# delay  100MB  5   50     # each 5th packet delayed by 50ms
# delay  100MB  5   100   
# delay  100MB  5   1500 
# drop   100MB  5          # each 5th packet dropped
# trunc  100MB  5   200    # each 5th packet truncated to 200 bytes
#
# To consider: what transport is used (ssh, scp, ftp, nc/udp, nc/tcp) 
#  
#
# A spec file like that would run three tests; each with 40ms of delay on 
# every 10th packet, with total transfer file sizes of 10, 20, and 30.
#
#set -e

SPECPATH=$1
DEST_IP=${2:-"192.241.195.88"} # set a default IP here
CLIENT_IP='129.170.212.165'

HOST_TESTING_DIR="$(hostname -i | awk '{print $1}')_to_$DEST_IP"
BIN_DIR='/home/max/vpn_client/packet-loser' # location of scripts

# From delay_udp
OUT_ETH=eth0
CIPHER=bf-cbc

if [ ! -f $SPECPATH ]; then
  echo "No such file, ya dummy."
  exit 1
fi

function mangle_delay() {
  DELAY_MS+=ms
  WHICH_IN_N=$(expr $NTH_PACKET - 1)
  MARK=777

  # delete old rules (this clears only the mangle table)
  iptables -t mangle -F

  # This rule marks outgoing packets for delay. Routing queues will
  #   put packets in the delaying queue if they match the mark.
  iptables -t mangle -A POSTROUTING -d $DEST_IP'/32' -o $OUT_ETH -m statistic --mode nth --every $NTH_PACKET --packet $WHICH_IN_N -j MARK --set-mark $MARK

  # delete queue tree on outgoing interface
  tc qdisc  del dev $OUT_ETH root

  # set up queues on outgoing interface
  tc qdisc  add dev $OUT_ETH root handle 1: prio
  tc qdisc  add dev $OUT_ETH parent 1:3 handle 30: netem delay $DELAY_MS
  tc filter add dev $OUT_ETH protocol ip parent 1:0 handle $MARK fw flowid 1:3
}

function mangle_drop() {
  WHICH_IN_N=$(expr $NTH_PACKET - 1)

  # delete old rules (this clears only the mangle table)
  iptables -t mangle -F

  # This rule marks outgoing packets for delay. Routing queues will
  #   put packets in the delaying queue if they match the mark.
  iptables -t mangle -A POSTROUTING -d $DEST_IP'/32' -o $OUT_ETH -m statistic --mode nth --every $NTH_PACKET --packet $WHICH_IN_N -j DROP
}

function demangle() {
  echo
  echo "Resetting iptables..."
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT
  iptables -F
  iptables -X

  echo "iptables reset."
}


# Main
mkdir $HOST_TESTING_DIR -p
cd $HOST_TESTING_DIR

TEST_SPECS=$(cat $SPECPATH)  # Grab all our specs into a variable

# IFS line delimited hack from http://blog.edwards-research.com/2010/01/quick-bash-trick-looping-through-output-lines/
OIFS="${IFS}"  # Save our old IFS (Internal Field Separator)
NIFS=$'\n'     # Save a new IFS (here, a newline)
IFS="${NIFS}"  # Set our IFS to the new one

for LINE in $TEST_SPECS  # This is where we need our IFS='\n'
do
  IFS="${OIFS}"
  read -a SPECS <<< "$LINE"  # Put our specs for the test into an array (IFS=' ')
  MANGLE_METHOD=${SPECS[0]}  # Can be 'delay' or 'drop'
  FILESIZE=${SPECS[1]}       # Size of the file to be transferred
  NTH_PACKET=${SPECS[2]}     # Size of n (operation applied to every nth packet)

  if [[ $MANGLE_METHOD == "delay" ]]; then
    DELAY_MS=${SPECS[3]}     # If we're delaying, grab the delay time
  fi

  IFS="${NIFS}"  # Reset IFS to '\n'

  # Name of directory to store testing data
  TEST_DIR='openvpn_delay'$DELAY_MS'_every'$NTH_PACKET'_'$CIPHER'_filesize'$FILESIZE'M'

  mkdir $TEST_DIR -p
  cd $TEST_DIR
  
  mangle_$MANGLE_METHOD

  # Start recording data
  tshark -i $OUT_ETH -w $TEST_DIR & CAPTURE_PID=$!

  # Transfer the sized file to our destination
  su max -c "ssh max@$CLIENT_IP '/home/max/storage/ists/vpn/packet-loser/create_and_scp.sh $FILESIZE $DEST_IP'"

  # Kill our packet capture
  kill $CAPTURE_PID
  
  demangle

  cd - &> /dev/null
done

IFS="${OIFS}"  # Reset our IFS
cd $BIN_DIR
