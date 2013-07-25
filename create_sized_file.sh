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
# usage: ./create_sized_file.sh <size_in_MB>
#   $1 = size of file to be created in MB
#
set -e

# directory where sized transfer files are stored
TESTING_DIR='transfer_files'

SIZE_IN_MB=$1
SIZE_IN_MB+=M # suffix number with 'M'

FILENAME=file_size$SIZE_IN_MB
FILEPATH=$TESTING_DIR/$FILENAME

create_file () {
  if [ ! -d $TESTING_DIR ]; then
    mkdir $TESTING_DIR
  fi
  
  if [ -f $FILEPATH ]; then
    echo "File of size $SIZE_IN_MB already exists, skipping creation." 1>&2
  else
    echo "Creating file of size $SIZE_IN_MB ..." 1>&2
    dd if=/dev/zero of=$FILEPATH bs=$SIZE_IN_MB count=1 &> /dev/null
    echo "File of size $SIZE_IN_MB created at $FILEPATH" 1>&2
  fi
}

create_file

echo $FILEPATH
exit 0
