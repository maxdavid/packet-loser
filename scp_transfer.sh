#!/bin/bash
# 
# Create a file of the given size (in megabytes) and transfer to target.
#
# If the directory "transfer_files" does not exist, it will be created and 
# filled with files named with their size for testing. 
#
# If a file of the requested size already exists, it will be used and a new 
# one will not be created.
#
# usage: ./scp_transfer.sh <target_ip> <size_in_MB>
#   $1 = target IP address
#   $2 = size of file to be created and transferred, in MB
#
set -e

# directory where sized transfer files are stored
TESTING_DIR='transfer_files'

# user:pass to scp as on target IP
REMOTE_USER='max'
REMOTE_PASS='Partytime1'
# location on target IP to transfer files to
REMOTE_DIR='/dev/null'

TARGET_IP=$1
SIZE_IN_MB=$2
SIZE_IN_MB+=M # suffix number with 'M'

FILENAME=file_size$SIZE_IN_MB


create_file () {
  if [ ! -d $TESTING_DIR ]; then
    mkdir $TESTING_DIR
  fi
  
  if [ -f $TESTING_DIR/$FILENAME ]; then
    echo "File of size $SIZE_IN_MB already exists, skipping creation."
  else
    echo "Creating file of size $SIZE_IN_MB ..."
    dd if=/dev/zero of=$TESTING_DIR/$FILENAME bs=$SIZE_IN_MB count=1 &> /dev/null
    echo "File of size $SIZE_IN_MB created at $TESTING_DIR/$FILENAME"
  fi
}

scp_to_target () {
  sshpass -p $REMOTE_PASS $TESTING_DIR/$FILENAME $REMOTE_USER@$TARGET_IP:$REMOTE_DIR
}

create_file
