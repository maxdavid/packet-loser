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
CLIENT_IP=$(hostname -i | awk '{print $1}')

if [ -z $TRANS_TYPE ]; then
  echo "No transfer method specified."
  echo "Pass either 'scp', 'ftp', 'nc-tcp', or 'nc-udp' as the first argument."
  exit 1
fi

BIN_DIR="/home/max/storage/ists/vpn/packet-loser"
TESTING_DIR="$BIN_DIR/transfer_files"

# scp information
SCP_USER=max
#SCP_PASS= (using a passwordless dsa key now)
SCP_DIR=/dev/null  # location on target IP to transfer files to

# ftp information
FTP_USER=anonymous
FTP_PASS=Partytime1
FTP_DIR=uploads

# netcat information
PORTNUM=4000          # for netcat


# Main

# Create the file and grab its path
FILENAME=$(pwd)/$($BIN_DIR/create_sized_file.sh $SIZE_IN_MB)

if [ "$TRANS_TYPE" == "scp" ]; then
  echo "Using scp to transfer a file of size $SIZE_IN_MB MB to $DEST_IP"
  scp $FILENAME $SCP_USER@$DEST_IP:$SCP_DIR

elif [ "$TRANS_TYPE" == "ftp" ]; then
  echo "Using ftp to transfer a file of size $SIZE_IN_MB MB to $DEST_IP"
  HASH=$(date +%N)  # Cannot overwrite files, so we'll just put them in hashed directories
  ncftpput -Vm -u $FTP_USER -p $FTP_PASS 192.241.195.88 $FTP_DIR/$HASH $FILENAME

elif [ "$TRANS_TYPE" == "nc-tcp" ]; then
  echo "Using netcat to transfer a file of size $SIZE_IN_MB MB to $DEST_IP over TCP"
  ssh -i ~/.ssh/id_dsa $SCP_USER@$DEST_IP "nc -dl $PORTNUM > wat.tmp &"
  cat "$FILENAME" | nc $DEST_IP $PORTNUM

elif [ "$TRANS_TYPE" == "nc-udp" ]; then
  echo "Using netcat to transfer a file of size $SIZE_IN_MB MB to $DEST_IP over UDP"
  ssh -i ~/.ssh/id_dsa $SCP_USER@$DEST_IP "nc -u -dl $PORTNUM > wat.tmp &"
  cat "$FILENAME" | nc -u -w5 $DEST_IP $PORTNUM  # -w5 seems to help data integrity
fi



