#!/bin/bash

DEST_IP=$1
CIPHER=$2
SCP="max@$DEST_IP:~/storage/ists/vpn/packet-loser/129.170.212.196_to_192.241.195.88/openvpn/$CIPHER"

if [ $3 = "." ]; then
  exit 0
fi

TARNAME=$(echo $3 | sed 's/^\.\///g')'.tar.gz'

echo "Creating archive $TARNAME"
tar czvf $TARNAME $3

echo "Copying archive to skipjack"
scp -i /home/max/.ssh/id_dsa $TARNAME $SCP/$TARNAME

rm -r $TARNAME
rm -r $3
