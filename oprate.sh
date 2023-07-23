#!/bin/bash

# Check if all required command-line arguments are provided
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Please provide the path to the openrc file, tag, and public key as command-line arguments."
    exit 1
fi

# Read the command-line arguments
openrc_file="$1"
tag="$2"
public_key="$3"
network_name="${tag}_network"
bastion_name="${tag}_bastion"
proxy_name="${tag}_proxy"

# Source the OpenStack environment variables from the provided OpenRC file
source "$openrc_file"

# Function to get the current number of nodes based on the servers.conf file
get_required_nodes() {
    if [ -f "servers.conf" ]; then
        required_nodes=$(grep -oE '[0-9]+' servers.conf | head -n 1)
        echo "$required_nodes"
    else
        echo "3"  # Default value if servers.conf is missing
    fi
}

# Function to check the current number of nodes
check_current_nodes() {
    nodes_info=$(openstack server list --format value -c Name)
    current_nodes=0
    for node in ${tag}_Node{1..9}; do
        if grep -q "$node" <<< "$nodes_info"; then
            current_nodes=$((current_nodes + 1))
        fi
    done
    echo "$current_nodes"
}

# Function to add a new node
add_node() {
    node_name="${tag}_Node$((current_nodes + 1))"
    openstack server create --flavor "$flavor" --image "$image_name" --network "$network_name" \
        --security-group "$SecurityGroup" --key-name "$KeyName" "$node_name"
    echo "Node $node_name added."
}

# Function to remove a node
remove_node() {
    node_name="${tag}_Node$current_nodes"
    openstack server delete "$node_name"
    echo "Node $node_name removed."
}

# Main loop to monitor the number of nodes
while true; do
    required_nodes=$(get_required_nodes)
    current_nodes=$(check_current_nodes)

    echo "Required nodes: $required_nodes, Current nodes: $current_nodes"

    if [ "$current_nodes" -lt "$required_nodes" ]; then
        nodes_to_add=$((required_nodes - current_nodes))
        for ((i = 0; i < nodes_to_add; i++)); do
            add_node
            current_nodes=$((current_nodes + 1))
        done
    elif [ "$current_nodes" -gt "$required_nodes" ]; then
        nodes_to_remove=$((current_nodes - required_nodes))
        for ((i = 0; i < nodes_to_remove; i++)); do
            remove_node
            current_nodes=$((current_nodes - 1))
        done
    fi

    sleep 30
done
