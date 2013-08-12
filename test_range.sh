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
#   2 - the file transfer method. can be 'scp', 'nc-tcp', 'nc-udp', or 'ftp'
#   3 - the size (in MB) of the file to be transferred.
#   4 - n, as in "operate on every nth packet"
#   5 - variable based on mangle type:
#         if using delay, the delay time in milliseconds (ms)
#         if using trunc, the number of bytes truncated from the packet
#
# An example spec file:
#
# delay  scp     100   5   50     # every 5th packet delayed by 50ms in a 100MB transfer
# delay  scp     100   5   100    # every 5th packet delayed by 100ms in a 100MB transfer
# delay  nc-tcp  100   10  150    # every 5th packet delayed by 150ms in a 100MB transfer
# drop   nc-tcp  100   5          # every 5th packet dropped in a 100MB transfer
# drop   nc-udp  100   10         # every 10th packet dropped in a 100MB transfer
# trunc  nc-udp  100   5   200    # every 5th packet truncated to 200 bytes in a 100MB transfer
#
# TODO: what transport is used (ssh, scp, ftp, nc/udp, nc/tcp) 
#  
# set -e

SPECPATH=$1
SERVER_IP=${2:-"192.241.195.88"}     # set a default server IP here
CLIENT_IP=${3:-"129.170.212.196"}    # set a default client IP here

VPN_TYPE=openvpn  # Type of VPN used (used for naming test data directory)
CIPHER=bf-cbc     # Cipher for VPN (used for naming test data directory)

BIN_DIR='/home/max/vpn_client/packet-loser'
OUT_IFACE=eth0   # Interface to operate on

if [ -z $SPECPATH ]; then
  echo "No spec file specified."
  exit 1
elif [ ! -f $SPECPATH ]; then
  echo "No such file, ya dummy."
  exit 1
elif [[ $(whoami) != 'root' ]]; then
  echo "You should probably run this as root."
  exit 1
fi


# Main
HOST_TESTING_DIR=$(pwd)/$CLIENT_IP"_to_"$SERVER_IP  # Name of dir for this test batch
mkdir $HOST_TESTING_DIR -p
cd $HOST_TESTING_DIR

TEST_SPECS=$(cat $SPECPATH)  # Grab all our specs into a variable

# IFS line delimited hack from http://blog.edwards-research.com/2010/01/quick-bash-trick-looping-through-output-lines/
OIFS="${IFS}"  # Save our old IFS (Internal Field Separator)
NIFS=$'\n'     # Save a new IFS (here, a newline)
IFS="${NIFS}"  # Set our IFS to the new one

COUNT=0
for LINE in $TEST_SPECS  # This is where we need our IFS='\n'
do
  COUNT=$(expr $COUNT + 1)
  echo "Starting Test $COUNT ------------------------------------------------"

  IFS="${OIFS}"  # Set IFS to ' ' for array parsing
  read -a SPECS <<< "$LINE"  # Put our specs for the test into an array
  MANGLE_TYPE=${SPECS[0]}    # Can be 'delay', 'drop', or 'trunc'
  TRANS_TYPE=${SPECS[1]}     # Can be 'scp', 'nc-tcp', 'nc-udp', or 'ftp'
  FILESIZE=${SPECS[2]}       # Size of the file to be transferred
  NTH_PACKET=${SPECS[3]}     # Size of n (operation applied to every nth packet)
  ADD_PARAM=${SPECS[4]}      # delay time or truncate len, depends on mangle type
  IFS="${NIFS}"  # Reset IFS to '\n'

  # Name of directory to store testing data
  TEST_DIR=$VPN_TYPE'_delay'$DELAY_MS'_every'$NTH_PACKET'_'$CIPHER'_filesize'$FILESIZE'M'

  mkdir $TEST_DIR -p
  cd $TEST_DIR
  
  $BIN_DIR/mangle.sh $SERVER_IP $MANGLE_TYPE $NTH_PACKET $ADD_PARAM

  # Start recording data
  tshark -i $OUT_IFACE -w $TEST_DIR 1> /dev/null & CAPTURE_PID=$!

  # Transfer the sized file to our destination
  su max -c "ssh max@$CLIENT_IP '/home/max/storage/ists/vpn/packet-loser/transfer.sh $TRANS_TYPE $FILESIZE $SERVER_IP'"

  # Kill our packet capture
  kill $CAPTURE_PID
  
  $BIN_DIR/mangle.sh $SERVER_IP 'clean'

  cd $HOST_TESTING_DIR &> /dev/null
done

IFS="${OIFS}"  # Reset our IFS
cd $BIN_DIR
