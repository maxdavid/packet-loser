#!/bin/bash
#
# Specify a range of specifications to be tested. The type of mangling, 
# transfer file size, nth space, and other specs can be written into a file 
# for batch testing.
#
# usage:
#   test_range.sh <spec_file> [<server_ip>] [<client_ip>]
#     $1 : file path of the spec file
#     $2 : server IP address (optional if defined below)
#     $3 : client IP address (optional if defined below)
# 
# Spec file is made simply. Each line is an individual test with parameters 
# separated by spaces. Each parameter, with its options:
#   1 - how to mangle the connection. can be delay, drop, trunc, or reset
#   2 - the size (in MB) of the file to be transferred.
#   3 - n, as in "operate on every nth packet"
#   4 - variable based on mangle type:
#         if using delay, the delay time in milliseconds (ms)
#         if using trunc, the number of bytes truncated from the packet
#
# An example spec file:
#
# delay  100   5   50     # every 5th packet delayed by 50ms in a 100MB transfer
# delay  100   5   100    # every 5th packet delayed by 100ms in a 100MB transfer
# delay  100   10  150    # every 5th packet delayed by 150ms in a 100MB transfer
# drop   100   5          # every 5th packet dropped in a 100MB transfer
# drop   100   10         # every 10th packet dropped in a 100MB transfer
# trunc  100   5   200    # every 5th packet truncated to 200 bytes in a 100MB transfer
#
# TODO: what transport is used (ssh, scp, ftp, nc/udp, nc/tcp) 
#  
# set -e

SPECPATH=$1
SERVER_IP=${2:-"192.241.195.88"}     # set a default server IP here
CLIENT_IP=${3:-"129.170.212.165"}    # set a default client IP here

VPN_TYPE=openvpn  # Type of VPN used (used for naming test data directory)
CIPHER=bf-cbc     # Cipher for VPN (used for naming test data directory)

BIN_DIR=$(dirname $BASH_SOURCE)
OUT_IFACE=eth0   # Interface to operate on

if [ ! -f $SPECPATH ]; then
  echo "No such file, ya dummy."
  exit 1
elif [[ ! $(whoami) == 'root' ]]; then
  echo "You should probably run this as root."
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
  iptables -t mangle -A POSTROUTING -d $SERVER_IP'/32' -o $OUT_IFACE -m statistic --mode nth --every $NTH_PACKET --packet $WHICH_IN_N -j MARK --set-mark $MARK

  # delete queue tree on outgoing interface
  tc qdisc  del dev $OUT_IFACE root

  # set up queues on outgoing interface
  tc qdisc  add dev $OUT_IFACE root handle 1: prio
  tc qdisc  add dev $OUT_IFACE parent 1:3 handle 30: netem delay $DELAY_MS
  tc filter add dev $OUT_IFACE protocol ip parent 1:0 handle $MARK fw flowid 1:3
}

function mangle_drop() {
  WHICH_IN_N=$(expr $NTH_PACKET - 1)

  # delete old rules (this clears only the mangle table)
  iptables -t mangle -F

  # This rule marks outgoing packets for delay. Routing queues will
  #   put packets in the delaying queue if they match the mark.
  iptables -t mangle -A POSTROUTING -d $SERVER_IP'/32' -o $OUT_IFACE -m statistic --mode nth --every $NTH_PACKET --packet $WHICH_IN_N -j DROP
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
HOST_TESTING_DIR=$(pwd)/$CLIENT_IP"_to_"$SERVER_IP  # Name of dir for this test batch
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
  elif [[ $MANGLE_METHOD == "trunc" ]]; then
    TRUNC_LEN=${SPECS[3]}    # If we're truncating, grab the num of bytes
  fi

  IFS="${NIFS}"  # Reset IFS to '\n'

  # Name of directory to store testing data
  TEST_DIR=$VPN_TYPE'_delay'$DELAY_MS'_every'$NTH_PACKET'_'$CIPHER'_filesize'$FILESIZE'M'

  mkdir $TEST_DIR -p
  cd $TEST_DIR
  
  mangle_$MANGLE_METHOD

  # Start recording data
  tshark -i $OUT_IFACE -w $TEST_DIR & CAPTURE_PID=$!

  # Transfer the sized file to our destination
  su max -c "ssh max@$CLIENT_IP '/home/max/storage/ists/vpn/packet-loser/create_and_scp.sh $FILESIZE $SERVER_IP'"

  # Kill our packet capture
  kill $CAPTURE_PID
  
  demangle

  cd $HOST_TESTING_DIR &> /dev/null
done

IFS="${OIFS}"  # Reset our IFS
cd $BIN_DIR
