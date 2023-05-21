#!/bin/bash
# Based on the work of Joe (Chorus-One) for Microtick - https://github.com/microtick/bounties/tree/main/statesync
# Updated by Raul Bernal for Bitcanna - https://github.com/BitCannaCommunity/cosmos-statesync_client
# RPC by Inter Blockchain Services
# ours statesync config:
#     [state-sync]
#     snapshot-interval = 1000
#     snapshot-keep-recent = 10

DAEMON_HOME="$HOME/.bcna"
DAEMON_NAME="bcnad"
NODE1_IP="bcna-rpc.ibs.team"
RPC1="https://$NODE1_IP"
RPC_PORT1=443
INTERVAL=2000

# Let's check if JQ tool is installed
FILE=$(which jq)
 if [ -f "$FILE" ]; then
   echo "JQ is present"
 else
   echo "$FILE JQ tool does not exist, install with: sudo apt install jq"
   exit 1
 fi
clear
set -e
echo
echo "Welcome to the StateSync script."
echo "This script will give you the info to configure StateSync in your validator"
echo "You should have a encrypted backup of your wallet keys, your node keys and your validator keys."
echo "Ensure that you can restore your wallet keys if is needed."
echo "Also ensure that $DAEMON_NAME/cosmovisor service is stopped."
echo ""
read -p "ATTENTION! This script will clear the data folder (unsafe-reset-all) & the Address Book PROCEED (y/n)? " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "\nClearing the data folder & P2P Address Book"
  $DAEMON_NAME tendermint unsafe-reset-all --home $DAEMON_HOME --keep-addr-book

  LATEST_HEIGHT=$(curl -s $RPC1:$RPC_PORT1/block | jq -r .result.block.header.height);
  BLOCK_HEIGHT=$((($(($LATEST_HEIGHT / $INTERVAL)) -10) * $INTERVAL)); #Mark addition from Microtick

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

  $DAEMON_NAME tendermint unsafe-reset-all --home $DAEMON_HOME
  echo ##################################################################
  echo  "PLEASE HIT CTRL+C WHEN THE CHAIN IS SYNCED, Wait the last block"
  echo ##################################################################
  sleep 5
  $DAEMON_NAME start
  sed -E -i 's/enable = true/enable = false/' $DAEMON_HOME/config/config.toml
  echo ##################################################################
  echo  Run again with: $DAEMON_NAME start
  echo ##################################################################
fi
