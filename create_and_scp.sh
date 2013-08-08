#!/bin/bash
# 
# Create a sized file and SCP it to a given IP. 
# user:pass and target dir are defined below.
#
# usage: ./scp_transfer.sh <size_in_MB> [<dest_ip>]
#   $1 = size in MB
#   $2 = destination IP address (optional if defined below)
#

# directory where sized transfer files are stored
TESTING_DIR=transfer_files
BIN_DIR='/home/max/storage/ists/vpn/packet-loser'

# user:pass to scp as on target IP
REMOTE_USER=max
REMOTE_PASS='Partytime1'
# location on target IP to transfer files to
REMOTE_DIR=/dev/null

SIZE_IN_MB=$1
DEST_IP=${2:-192.241.195.88} # define default destination ip here

FILENAME=$(pwd)/$($BIN_DIR/create_sized_file.sh $SIZE_IN_MB)

echo "Using scp to transfer a file of size $SIZE_IN_MB MB to $DEST_IP"
scp $FILENAME $REMOTE_USER@$DEST_IP:$REMOTE_DIR

