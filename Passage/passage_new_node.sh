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
BINARY="https://ibs.team/statesync/Passage/passage"
GENESIS="https://ibs.team/statesync/Passage/genesis.json"
DAEMON_HOME="$HOME/.passage"
DAEMON_NAME="passage"
BINARYNAME="passage"
CHAINID="passage-1"
SEEDS="aebb8431609cb126a977592446f5de252d8b7fa1@104.236.201.138:26656,b6beabfb9309330944f44a1686742c2751748b83@5.161.47.163:26656,7a9a36630523f54c1a0d56fc01e0e153fd11a53d@167.235.24.145:26656"
GASPRICE="0upasg"
RPC1="http://75.119.157.167"
RPC_PORT1=31657
INTERVAL=1000


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
    echo "There is a $DAEMON_NAME folder there..."
    exit 1
  else
      echo "New installation...."
  fi

  if [ -f $DAEMON_HOME ];
   then
    rm -f $BINARYNAME	#deletes a previous downloaded binary
  fi
  wget -nc $BINARY
  chmod +x $BINARYNAME
  cp $BINARYNAME go/bin/
  ./$BINARYNAME init New_peer --chain-id $CHAINID --home $DAEMON_HOME
  rm -rf $DAEMON_HOME/config/genesis.json #deletes the default created genesis
  curl -s $GENESIS > $DAEMON_HOME/config/genesis.json

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

  sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
  s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$RPC1:$RPC_PORT1,$RPC1:$RPC_PORT1\"| ; \
  s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
  s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"| ; \
  s|^(persistent_peers[[:space:]]+=[[:space:]]+).*$|\1\"${NODE1_ID}@${NODE1_LISTEN_ADD}\"| ; \
  s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"$SEEDS\"|" $DAEMON_HOME/config/config.toml


  sed -E -i -s 's/minimum-gas-prices = \".*\"/minimum-gas-prices = \"0upasg\"/' $DAEMON_HOME/config/app.toml

  ./$BINARYNAME tendermint unsafe-reset-all --home $DAEMON_HOME
  echo ##################################################################
  echo  "PLEASE HIT CTRL+C WHEN THE CHAIN IS SYNCED, Wait the last block"
  echo ##################################################################
  sleep 5
  ./$BINARYNAME start
  sed -E -i 's/enable = true/enable = false/' $DAEMON_HOME/config/config.toml
  echo ##################################################################
  echo  Run again with: ./$BINARYNAME start
  echo ##################################################################
fi
