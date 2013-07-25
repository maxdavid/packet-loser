#!/bin/bash
# 
# SCP a file to a given IP. user:pass and target dir are defined below.
#
# usage: ./scp_transfer.sh <target_ip>
#   $1 = target IP address
#   $2 = file to be transferred
#

# directory where sized transfer files are stored
TESTING_DIR='transfer_files'

# user:pass to scp as on target IP
REMOTE_USER='max'
REMOTE_PASS='Partytime1'
# location on target IP to transfer files to
REMOTE_DIR='/dev/null'

TARGET_IP=$1
FILENAME=$2


sshpass -p $REMOTE_PASS $FILENAME $REMOTE_USER@$TARGET_IP:$REMOTE_DIR

