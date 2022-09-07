#!/bin/bash
# Based on the work of Joe (Chorus-One) for Microtick - https://github.com/microtick/bounties/tree/main/statesync
# You need config in two peers (avoid seed servers) this values in app.toml:
#     [state-sync]
#     snapshot-interval = 1000
#     snapshot-keep-recent = 10
# Pruning should be fine tuned also, for this testings is set to nothing
#     pruning = "~default"

# Let's check if JQ tool is installed
FILE=$(which jq)
 if [ -f "$FILE" ]; then
 echo "JQ is present"
 else
 echo "$FILE JQ tool does not exist, install with: sudo apt install jq"
 exit 1
 fi
FILE=$(which git)
 if [ -f "$FILE" ]; then
 echo "GIT is present"
 else
 echo "$FILE GIT tool does not exist, install with: sudo apt install git"
 exit 1
 fi
FILE=$(which go)
 if [ -f "$FILE" ]; then
 echo "GO is present"
 else
 echo "$FILE GO tool does not exist, install with: wget -q -O - https://git.io/vQhTU | bash -s -- --version 1.18.6"
 exit 1
 fi

set -e
REPO="https://github.com/BitCannaGlobal/bcna.git"
GENESIS="https://ibs.team/statesync/Bitcana/genesis.json"
DAEMON_HOME="$HOME/.bcna"
DAEMON_NAME="bcnad"
BINARYNAME="bcnad"
CHAINID="bitcanna-1"
SEEDS=""
GASPRICE="0.001ubcna"
RPC1="http://161.97.156.216"
RPC_PORT1=26657
INTERVAL=100


echo "Welcome to the StateSync script. This script will build the last binary and it will sync the last state."
echo "DON'T USE WITH A EXISTENT peer/validator config will be erased."

  cd ~
  if [ -d $DAEMON_HOME ];
  then
    echo "There is a $DAEMON_NAME folder there..."
    exit 1
  else
      echo "Build bcnad...."
  fi

  git clone https://github.com/BitCannaGlobal/bcna.git
  cd bcna
  git checkout v1.4.2
  make install
  cd ~
  $BINARYNAME init New_peer --chain-id $CHAINID --home $DAEMON_HOME
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


  sed -E -i -s 's/minimum-gas-prices = \".*\"/minimum-gas-prices = \"0.001ubcna\"/' $DAEMON_HOME/config/app.toml

  $BINARYNAME tendermint unsafe-reset-all --home $DAEMON_HOME
  echo ##################################################################
  echo  "PLEASE HIT CTRL+C WHEN THE CHAIN IS SYNCED, Wait the last block"
  echo ##################################################################
  sleep 5
  $BINARYNAME start
  sed -E -i 's/enable = true/enable = false/' $DAEMON_HOME/config/config.toml
  echo ##################################################################
  echo  Run again with: ./$BINARYNAME start
  echo ##################################################################
fi
