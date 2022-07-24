#!/bin/bash
# Based on the work of Joe (Chorus-One) for Microtick - https://github.com/microtick/bounties/tree/main/statesync
# Updated by Raul Bernal for Bitcanna - https://github.com/BitCannaCommunity/cosmos-statesync_client
# RPC by IBS
# ours statesync config:
#     [state-sync]
#     snapshot-interval = 100
#     snapshot-keep-recent = 10

DAEMON_HOME="$HOME/.bcna"
DAEMON_NAME="bcnad"



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
  $DAEMON_NAME unsafe-reset-all

  NODE1_IP="bcna-statesync.ibs.team"
  RPC1="https://$NODE1_IP"
  P2P_PORT1=30656
  RPC_PORT1=443

  NODE2_IP="bcna-statesync.ibs.team"
  RPC2="https://$NODE2_IP"
  P2P_PORT2=30656
  RPC_PORT2=443

  #If you want to use a third StateSync Server...
  #DOMAIN_3=XXX.io     # If you want to use domain names
  #NODE3_IP=$(dig $DOMAIN_1 +short
  #RPC3="http://$NODE3_IP"
  #RPC_PORT3=26657
  #P2P_PORT3=26656

  INTERVAL=1000

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

  NODE2_ID=$(curl -s "$RPC2:$RPC_PORT2/status" | jq -r .result.node_info.id)
  #NODE3_ID=$(curl -s "$RPC3:$RPC_PORT3/status" | jq -r .result.node_info.id)
  echo ""
  echo "##################################################################"
  echo "#     Parameters to change in: $DAEMON_HOME/config/config.toml          #"
  echo "##################################################################"
  echo "#  Temporaly search and replace this params with this values     #"
  echo "##################################################################"
  echo ""
  echo "persistent_peers = \"${NODE1_ID}@${NODE1_LISTEN_ADD}:${P2P_PORT1}\""
  echo ""
  echo "Go to -StateSync section-"
  echo "========================="
  echo 'enable = true'
  echo "rpc_servers = \"https://$NODE1_IP:$RPC_PORT1,https://$NODE2_IP:$RPC_PORT2\""
  echo "trust_height = $BLOCK_HEIGHT"
  echo "trust_hash = \"$TRUST_HASH\""
  echo ""
  echo '##################################################################################'
  echo "#           Start the daemon with this new settings, when is synced              #"
  echo "##################################################################################"
  echo "# 1) Stop it again and change in the same file: config.toml this param again!!!  #"
  echo '#     enable = false                                                             #'
  echo '#                                                                                #'
  echo '##################################################################################'
  echo '#                Now you can start the daemon again! Good luck!                  #'
  echo '##################################################################################'
  sleep 5
fi
