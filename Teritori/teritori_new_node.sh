#!/bin/bash
# Based on the work of Joe Bowman for Microtick - https://github.com/microtick/bounties/tree/main/statesync
# You need config in two peers (avoid seed servers) this values in app.toml:
#     [state-sync]
#     snapshot-interval = 1000
#     snapshot-keep-recent = 10
# Pruning should be fine tuned also, for this testings is set to nothing
#     pruning = "~default"


set -e
REPO="https://github.com/TERITORI/teritori-chain"
REPODIRECTORY="$HOME/teritori-chain"
GENESIS="https://media.githubusercontent.com/media/TERITORI/teritori-mainnet-genesis/main/genesis.json"
BINARYNAME="teritorid"
VERSION="v1.3.0"
DAEMON_HOME="$HOME/.teritorid"
CHAINID="teritori-1"
SEEDS=""
RPC1="http://38.242.232.202"
RPC_PORT1=29657
INTERVAL=100
GOVERSION="1.19.2"

clear
echo "###################################################################"
echo " "
echo " update the local package list and install any available upgrades"
echo " "
echo "###################################################################"
sleep 3
sudo apt-get update && sudo apt upgrade -y

clear
echo "##################################################################"
echo " "
echo "   install toolchain and ensure accurate time synchronization"
echo " "
echo "##################################################################"
sleep 3
sudo apt-get install make build-essential gcc git jq chrony curl -y

clear
echo "##################################################################"
echo " "
echo "                     install go $GOVERSION"
echo " "
echo "##################################################################"
sleep 3

 if [ -d "$GOROOT" ];
 then
 sudo rm -r $GOROOT
 fi

 wget -q -O - https://git.io/vQhTU | bash -s -- --version $GOVERSION
 source $HOME/.bashrc

clear
echo "#########################################################################################################"
echo " "
echo "Welcome to the StateSync script. This script will build the last binary and it will sync the last state."
echo "             DON'T USE WITH A EXISTENT peer/validator config will be erased"
echo " "
echo "#########################################################################################################"
sleep 2
  cd ~
  if [ -d $DAEMON_HOME ];
  then
    echo "There is a $BINARYNAME folder there..."
    exit 1
  else
      echo "Build $BINARYNAME...."
  fi

  if [ -d $REPODIRECTORY ]; 
  then
    sudo rm -r $REPODIRECTORY
  fi

  GOROOT=$HOME/.go
  GOPATH=$HOME/go
  PATH=$PATH:$GOROOT/bin:$GOPATH/bin

  git clone $REPO
  cd $REPODIRECTORY
  git checkout $VERSION
  make install
  cd ~
  $BINARYNAME init New_peer --chain-id $CHAINID --home $DAEMON_HOME
  rm -rf $DAEMON_HOME/config/genesis.json 
  curl -s $GENESIS > $DAEMON_HOME/config/genesis.json

  LATEST_HEIGHT=$(curl -s $RPC1:$RPC_PORT1/block | jq -r .result.block.header.height);
  BLOCK_HEIGHT=$((($(($LATEST_HEIGHT / $INTERVAL)) -10) * $INTERVAL)); #Mark from Microtick addition

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

  sed -E -i -s 's/minimum-gas-prices = \".*\"/minimum-gas-prices = \"0.0025ustars\"/' $DAEMON_HOME/config/app.toml

  $BINARYNAME tendermint unsafe-reset-all --home $DAEMON_HOME

  clear

  echo "###################################################################"
  echo " "
  echo "  PLEASE HIT CTRL+C WHEN THE CHAIN IS SYNCED, Wait the last block"
  echo " "
  echo "###################################################################"
  sleep 5
  $BINARYNAME start
  sed -E -i 's/enable = true/enable = false/' $DAEMON_HOME/config/config.toml

  clear

  read -p "Do you want create a service (y/n)? " -n 1 -r
  clear
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo  "[Unit]
  Description=$BINARYNAME 
  After=network-online.target
  
  [Service]
  User=$USER
  ExecStart=$(which $BINARYNAME) start
  Restart=on-failure
  RestartSec=3
  LimitNOFILE=65535
  
  [Install]
  WantedBy=multi-user.target" > $BINARYNAME.service

  sudo mv $BINARYNAME.service /etc/systemd/system/$BINARYNAME.service
  sudo systemctl daemon-reload && sudo systemctl enable $BINARYNAME
  sudo systemctl start $BINARYNAME

  echo "##################################################################"
  echo " "
  echo "                Service is running to check Log run"
  echo "                 sudo journalctl -fu $BINARYNAME"
  echo "                            ENJOY"
  echo "##################################################################"

else
  echo "################################################################"
  echo " "
  echo "        $BINARYNAME is installed and synced on your server"
  echo "                You can start $BINARYNAME with"
  echo "                      $BINARYNAME start"
  echo "                            ENJOY"
  echo " "
  echo "#################################################################"

fi
