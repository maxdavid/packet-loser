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

SPECPATH=$1
DEST_IP=${2:-"129.170.213.70/32"} # set a default IP here

BIN_DIR='.' # location of scripts

if [ ! -f $SPECPATH ]; then
  echo "No such file, ya dummy."
  exit 1
fi

while read LINE
do
  read -a SPECS <<< $LINE
  # Get the filepath of the file to be transferred
  TRANS_FILE=$($BIN_DIR/create_sized_file.sh ${SPECS[0]})
  # Start delaying every n packets to our target
  $BIN_DIR/delay_udp.sh ${SPECS[1]} ${SPECS[2]} $DEST_IP &
  # Grab the pid (so we can kill it later)
  DELAY_PID=$!
  # Transfer the sized file to our destination
  $BIN_DIR/scp_transfer.sh $TRANS_FILE $DEST_IP
  # Kill our packet capture
  kill -9 $DELAY_PID

done < $SPECPATH
