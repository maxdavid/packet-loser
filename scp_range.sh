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
#   10 40 10
#   20 40 10
#   30 40 10
#
# A spec file like that would run three tests; each with 40ms of delay on 
# every 10th packet, with total transfer file sizes of 10, 20, and 30.
#
set -e

SPECPATH=$1
DEST_IP=${2:-"192.241.195.88"} # set a default IP here
CLIENT_IP='129.170.212.165'

HOST_TESTING_DIR="$(hostname -i | awk '{print $1}')_to_$DEST_IP"
BIN_DIR='/home/max/vpn_client/test_scripts' # location of scripts

# From delay_udp
OUT_ETH=eth0
CIPHER=bf-cbc

if [ ! -f $SPECPATH ]; then
  echo "No such file, ya dummy."
  exit 1
fi


# Main
mkdir $HOST_TESTING_DIR -p
chown max $HOST_TESTING_DIR
cd $HOST_TESTING_DIR

while read LINE
do
  # Put our specs for the test into an array
  read -a SPECS <<< $LINE
  FILESIZE=${SPECS[0]}
  DELAY_MS=${SPECS[1]}
  NTH_DELAY=${SPECS[2]}

  # Name of directory to store testing data
  TEST_DIR='openvpn_delay'$DELAY_MS'_every'$NTH_DELAY'_'$CIPHER'_filesize'$FILESIZE'M'

  mkdir $TEST_DIR -p
  chown max $TEST_DIR
  cd $TEST_DIR
  
  # Start recording data
  su max -c "tshark -i $OUT_ETH -w $TEST_DIR -b filesize:1024 & echo \$! > /tmp/su.tshark.$$"

  # Transfer the sized file to our destination
  su -c "ssh max@$CLIENT_IP '/home/max/storage/ists/vpn/packet-loser/create_and_transfer.sh $FILESIZE'" max

  # Kill our packet capture
  kill -9 $(cat /tmp/su.tshark.$$)

  cd -

done < $SPECPATH

