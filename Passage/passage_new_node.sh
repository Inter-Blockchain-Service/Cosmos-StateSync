#!/bin/bash
# Based on the work of Joe (Chorus-One) for Microtick - https://github.com/microtick/bounties/tree/main/statesync
# You need config in two peers (avoid seed servers) this values in app.toml:
#     [state-sync]
#     snapshot-interval = 1000
#     snapshot-keep-recent = 10
# Pruning should be fine tuned also, for this testings is set to nothing
#     pruning = "~default"

# Let's check if GO is installed
FILE=$(which go)
 if [ -f "$FILE" ]; then
 echo "GO is present"
 else
 echo "$FILE GO tool does not exist, install with: wget -q -O - https://git.io/vQhTU | bash -s -- --version 1.18.6"
 exit 1
 fi

echo "update the local package list and install any available upgrades"
sudo apt-get update && sudo apt upgrade -y
echo "install toolchain and ensure accurate time synchronization"
sudo apt-get install make build-essential gcc git jq chrony -y

set -e
REPO="https://github.com/envadiv/Passage3D"
GENESIS="https://ibs.team/statesync/Passage/genesis.json"
DAEMON_HOME="$HOME/.passage"
DAEMON_NAME="passage"
CHAINID="passage-1"
SEEDS=""
RPC1="http://75.119.157.167"
RPC_PORT1=31657
INTERVAL=1000
REPODIRECTORY="Passage3D"
VERSION="v1.0.0"

clear
echo "#########################################################################################################"
echo "Welcome to the StateSync script. This script will build the last binary and it will sync the last state."
echo "DON'T USE WITH A EXISTENT peer/validator config will be erased."
echo "#########################################################################################################"
sleep 1
  cd ~
  if [ -d $DAEMON_HOME ];
  then
    echo "There is a $DAEMON_NAME folder there..."
    exit 1
  else
      echo "Build $DAEMON_NAME...."
  fi

  if [ -d $REPODIRECTORY ]; 
  then
    sudo rm -r $REPODIRECTORY
  fi

  git clone $REPO
  cd $REPODIRECTORY
  git checkout $VERSION
  make install
  cd ~
  $DAEMON_NAME init New_peer --chain-id $CHAINID --home $DAEMON_HOME
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

  $DAEMON_NAME tendermint unsafe-reset-all --home $DAEMON_HOME

  clear

  echo "##################################################################"
  echo  "PLEASE HIT CTRL+C WHEN THE CHAIN IS SYNCED, Wait the last block"
  echo "##################################################################"
  sleep 5
  $DAEMON_NAME start --home $DAEMON_HOME
  sed -E -i 's/enable = true/enable = false/' $DAEMON_HOME/config/config.toml

  clear

  echo "##################################################################"
  echo             $DAEMON_NAME is installed and synced
  echo "##################################################################"
  echo            You can now create a service with :
  echo
  echo  "sudo tee /etc/systemd/system/$DAEMON_NAME.service > /dev/null <<EOF"
  echo  "[Unit]"
  echo  "Description=$DAEMON_NAME Service"
  echo  "After=network-online.target"
  echo
  echo  "[Service]"
  echo  "User=$USER"
  echo  "ExecStart=$(which $DAEMON_NAME) start"
  echo  "Restart=on-failure"
  echo  "RestartSec=3"
  echo  "LimitNOFILE=65535"
  echo
  echo  "[Install]"
  echo  "WantedBy=multi-user.target"
  echo  "EOF"
  echo "##################################################################"
  echo             To enable service at start
  echo    "sudo systemctl daemon-reload && sudo systemctl enable $DAEMON_NAME"
  echo
  echo                To start service run
  echo               "sudo systemctl start $DAEMON_NAME"
  echo
  echo                  To check logs run
  echo               "sudo journalctl -fu $DAEMON_NAME"
  echo
  echo                         ENJOY
  echo "##################################################################"

