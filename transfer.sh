#!/bin/bash
# 
# Create a sized file and transfer it to a given IP. 
# user:pass and target dir are defined below.
#
# usage: ./scp_transfer.sh <transfer_method> [<size_in_MB>] [<dest_ip>]
#   $1 = transfer method (see options below)
#   $2 = size in MB (optional, defaults to 100MB)
#   $3 = destination IP address (optional if defined below)
#
# Transfer Methods
#   scp    - Secure copy, transfers the file over ssh.
#   ftp    - Transfer the file over File Transfer Protocol
#   nc-tcp - Use netcat to transfer the file over TCP
#   nc-udp - Use netcat to transfer the file over UDP
#

TRANS_TYPE=$1
SIZE_IN_MB=${2:-100}
DEST_IP=${3:-192.241.195.88} # define default destination ip here

if [ -z $TRANS_TYPE ]; then
  echo "No transfer method specified."
  echo "Pass either 'scp', 'ftp', 'nc-tcp', or 'nc-udp' as the first argument."
  exit 1
fi

TESTING_DIR=transfer_files  # directory where sized transfer files are stored
BIN_DIR='/home/max/storage/ists/vpn/packet-loser'

# scp information
REMOTE_USER=max
#REMOTE_PASS= (using a passwordless dsa key now)
REMOTE_DIR=/dev/null  # location on target IP to transfer files to


# Main

# Create the file and grab its path
FILENAME=$(pwd)/$($BIN_DIR/create_sized_file.sh $SIZE_IN_MB)

if [ "$TRANS_TYPE" == "scp" ]; then
  echo "Using scp to transfer a file of size $SIZE_IN_MB MB to $DEST_IP"
  scp $FILENAME $REMOTE_USER@$DEST_IP:$REMOTE_DIR
fi



