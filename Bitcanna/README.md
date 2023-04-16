The first thing is to configure your node for statesync :

```
SNAP_RPC="https://bcna-rpc.ibs.team:443"

LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height); \
BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000)); \
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"|" $HOME/.bcna/config/config.toml
```

After stop your node :

```
sudo systemctl stop bcnad
```

Clear your data directory :

```
bcnad tendermint unsafe-reset-all --home $HOME/.bcna --keep-addr-book
```

start your node and wait the sync :

```
bcnad start
```

When your node is sync stop tour daemon with Ctrl + c, disable statesync and restart your service :

```
sed -E -i 's/enable = true/enable = false/' HOME/.bcna/config/config.toml
sudo systemctl start bcnad
```
