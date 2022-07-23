#!/bin/bash
# Based on the work of Joe (Chorus-One) for Microtick - https://github.com/microtick/bounties/tree/main/statesync
# You need config in two peers (avoid seed servers) this values in app.toml:
#     [state-sync]
#     snapshot-interval = 1000
#     snapshot-keep-recent = 10
# Pruning should be fine tuned also, for this testings is set to nothing
#     pruning = "nothing"

# Let's check if JQ tool is installed
FILE=$(which jq)
 if [ -f "$FILE" ]; then
 echo "JQ is present"
 else
 echo "$FILE JQ tool does not exist, install with: sudo apt install jq"
 fi

set -e

# Change for your custom chain
BINARY="https://github.com/ixofoundation/ixo-blockchain/releases/download/v0.16.0/ixod-1.6.0-linux-amd64"
GENESIS="https://raw.githubusercontent.com/ixofoundation/genesis/master/impacthub-3/genesis.json"
DAEMON_HOME="$HOME/.ixod"
DAEMON_NAME="ixod"
BINARYNAME="ixod"
DOWNLOADNAME="ixod-1.6.0-linux-amd64"
CHAINID="impacthub-3"
SEEDS=""
GASPRICE="0.025uixo"



echo "Welcome to the StateSync script. This script will download the last binary and it will sync the last state."
echo "DON'T USE WITH A EXISTENT peer/validator config will be erased."
echo "You should have a crypted backup of your wallet keys, your node keys and your validator keys." 
echo "Ensure that you can restore your wallet keys if is needed."
read -p "have you stopped the $DAEMON_NAME service? CTRL + C to exit or any key to continue..."
read -p "$DAEMON_HOME folder, your keys and config WILL BE ERASED, it's ok if you want to build a peer/validator for first time, PROCED (y/n)? " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
  #  State Sync client config.
  echo ##################################################
  echo " Making a backup from $DAEMON_NAME config files if exist"
  echo ##################################################
  cd ~
  if [ -d $DAEMON_HOME ];
  then
    echo "There is a $DAEMON_NAME folder there... if you want sync the data in an existent peer/validator try the script: statesync_linux_with_backup.sh"
    exit 1
  else
      echo "New installation...."
  fi

  if [ -f $DAEMON_HOME ];
   then
    rm -f $BINARYNAME	#deletes a previous downloaded binary
  fi
  wget -nc $BINARY
  chmod +x $DOWNLOADNAME
  mv $DOWNLOADNAME $BINARYNAME
  cp $BINARYNAME go/bin/
  ./$BINARYNAME init New_peer --chain-id $CHAINID
  rm -rf $DAEMON_HOME/config/genesis.json #deletes the default created genesis
  curl -s $GENESIS > $DAEMON_HOME/config/genesis.json

  RPC1="https://ixo-statesync.ibs.team"
  RPC_PORT1=443

  #NODE2_IP="159.65.198.245"
  #RPC2="http://$NODE2_IP"
  #RPC_PORT2=26657
  #P2P_PORT2=26656

  #If you want to use a third StateSync Server... 
  #DOMAIN_3=seed1.bitcanna.io     # If you want to use domain names 
  #NODE3_IP=$(dig $DOMAIN_1 +short
  #RPC3="http://$NODE3_IP"
  #RPC_PORT3=26657
  #P2P_PORT3=26656

  INTERVAL=1000

  LATEST_HEIGHT=$(curl -s $RPC1:$RPC_PORT1/block | jq -r .result.block.header.height);
  BLOCK_HEIGHT=$((($(($LATEST_HEIGHT / $INTERVAL)) -10) * $INTERVAL)); #Mark addition
  
  if [ $BLOCK_HEIGHT -eq 0 ]; then
    echo "Error: Cannot state sync to block 0; Latest block is $LATEST_HEIGHT and must be at least $INTERVAL; wait a few blocks!"
    exit 1
  fi

  TRUST_HASH=$(curl -s "$RPC1:$RPC_PORT1/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)
  if [ "$TRUST_HASH" == "null" ]; then
    echo "Error: Cannot find block hash. This shouldn't happen :/"
    exit 1
  fi

  NODE1_ID=$(curl -s "$RPC1:$RPC_PORT1/status" | jq -r .result.node_info.id)
  NODE1_LISTEN_ADD=$(curl -s "$RPC1:$RPC_PORT1/status" | jq -r .result.node_info.listen_addr)
  #NODE2_ID=$(curl -s "$RPC2:$RPC_PORT2/status" | jq -r .result.node_info.id)
  #NODE3_ID=$(curl -s "$RPC3:$RPC_PORT3/status" | jq -r .result.node_info.id)

  sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
  s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$RPC1:$RPC_PORT1,$RPC1:$RPC_PORT1\"| ; \
  s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
  s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"| ; \
  s|^(persistent_peers[[:space:]]+=[[:space:]]+).*$|\1\"${NODE1_ID}@${NODE1_LISTEN_ADD}\"| ; \
  s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"$SEEDS\"|" $DAEMON_HOME/config/config.toml


  sed -E -i -s 's/minimum-gas-prices = \".*\"/minimum-gas-prices = \"0.025ixo\"/' $DAEMON_HOME/config/app.toml

  ./$BINARYNAME unsafe-reset-all
  echo ##################################################################
  echo  "PLEASE HIT CTRL+C WHEN THE CHAIN IS SYNCED, Wait the last block"
  echo ##################################################################
  sleep 5
  ./$BINARYNAME start
  sed -E -i 's/enable = true/enable = false/' $DAEMON_HOME/config/config.toml
  echo ##################################################################  
  echo  Run again with: ./$BINARYNAME start
  echo ##################################################################
  echo If your node is synced considerate to create a service file. Be careful, your backup file is not crypted!
  echo If process was sucessful you can delete .old_$DAEMON_NAME
fi
