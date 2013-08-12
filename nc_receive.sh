#!/bin/bash
#
# Start listening for a netcat transmission, then send it from another
# host.
#
# usage:
#   nc_receive.sh <client_ssh> <file_path> [<transfer_type>]
#     $1 : the ssh login of the host to send from
#     $2 : file path of the file to be transferred
#     $3 : type of transfer, tcp or udp (defaults to tcp)

CLIENT_SSH=${1:-"max@129.170.212.196"}
FILEPATH=${2:-"/home/max/storage/ists/vpn/packet-loser/transfer_files/file_size10M"}
NC_TYPE=${3:-"tcp"}
PORTNUM=4000

SERVER_IP=192.241.195.88

if [ -z $CLIENT_SSH ]; then
  echo "Client user:IP not specified."
  exit 1
elif [ -z $FILEPATH ]; then
  echo "No target file path specified."
  exit 1
fi

nc -dl $PORTNUM > wat.tmp &

ssh -i ~/.ssh/id_dsa $CLIENT_SSH "cat $FILEPATH | nc $SERVER_IP $PORTNUM"
