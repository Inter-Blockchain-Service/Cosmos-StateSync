# Cosmos-StateSync

First thing, if you are running a validator BACKUP your priv_validator_key.json.

Choose the network you wan't to sync, you will find manual step in readme, or you can use one of our scripts.

XXXX_new_node.sh script can be used on a FRESH VPS. It will update your system, install go, compile the binary, statesynced chain  and will ask you to create a service or not. If there is go installed, it will remove and reinstall it. 

XXXX_existing_node.sh script will put the good params in config.toml for statesync, clear your data, sync your node, and then disabled state sync.
