# Cosmos-StateSync

First thing , if you are running a validator BACKUP your config directory .

There is 2 scripts by chain : XXXX_new_node.sh and XXXX_existing_node.sh

New node script can be used on a FRESH VPS .
It will update your system , install go , compile the binary , statesynced chain  and will ask you to create a service or not.

If there is go installed , it will remove and reinstall it . 

Existing node script will put the good params in config.toml  sync it using statesync and then disabled state sync .

Once your node is sync , please consider to make a service .
