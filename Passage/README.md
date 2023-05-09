# Passage statesync by Inter Blockchain Services

If you are running a validator BACKUP your priv_validator_key.json.

## You can use one of our scripts

passage_new_node.sh script can be used on a FRESH VPS. It will update your system, install go, compile the binary, statesynced chain and will ask you to create a service or not. If there is go installed, it will remove and reinstall it.

```
wget https://raw.githubusercontent.com/Inter-Blockchain-Service/Cosmos-StateSync/main/Passage/passage_new_node.sh
chmod +x passage_new_node.sh
./passage_new_node.sh
```

passage_existing_node.sh script will put the good params in config.toml for statesync, clear your data, sync your node, and then disabled state sync. Once your node is sync , please consider to make a service .

```
wget https://raw.githubusercontent.com/Inter-Blockchain-Service/Cosmos-StateSync/main/Passage/passage_existing_node.sh
chmod +x passage_existing_node.sh
./passage_existing_node.sh
```

## Or copy and paste the following commands

The first thing is to configure your node for statesync :

```
SNAP_RPC="https://passage-rpc.ibs.team:443"

LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height); \
BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000)); \
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"|" $HOME/.passage/config/config.toml
```

After stop your node and clear your data :

```
sudo systemctl stop passage
passage tendermint unsafe-reset-all --home $HOME/.passage --keep-addr-book
```

Then start passage daemon and wait the sync :

```
passage start
```

Finally when your node is sync stop the daemon with Ctrl + c, disable statesync and restart your service :

```
sed -E -i 's/enable = true/enable = false/' HOME/.passage/config/config.toml
sudo systemctl start passage
```
