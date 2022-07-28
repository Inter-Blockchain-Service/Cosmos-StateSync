# Cosmos-StateSync

First thing , if you are running a validator BACKUP your config directory .

There is 2 scripts by chain : XXXX_new_node.sh and XXXX_existing_node.sh

New node script have to be use on a VPS where there is no binary but go and jq need to be installed . 
It will reset the node and sync it using statesync and then disabled state sync .

Existing node script will put the good params in config.toml  sync it using statesync and then disabled state sync .

Once your node is sync , please consider to make a service .
