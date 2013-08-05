#!/bin/bash
# 
# SCP a file to a given IP. user:pass and target dir are defined below.
#
# usage: ./scp_transfer.sh <transfer_file> [<dest_ip>]
#   $1 = file to be transferred
#   $2 = destination IP address (optional if defined below)
#

# directory where sized transfer files are stored
TESTING_DIR=transfer_files

# user:pass to scp as on target IP
REMOTE_USER=max
REMOTE_PASS='Partytime1'
# location on target IP to transfer files to
REMOTE_DIR=/dev/null

FILENAME=$1
DEST_IP=${2:-129.170.213.70} # define default destination ip here

scp $FILENAME $REMOTE_USER@$DEST_IP:$REMOTE_DIR

