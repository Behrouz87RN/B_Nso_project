#!/bin/bash

# Check if a Tag is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <Tag>"
  exit 1
fi

# Read the provided Tag from the command-line argument
Tag="$1"
router_name="${Tag}_router"

# Check if a keypair with the specified Tag exists and delete it
keypair_name=$(openstack keypair list -f value -c Name | grep $Tag)
if [ -n "$keypair_name" ]; then
  openstack keypair delete "$keypair_name"
  if [ $? -eq 0 ]; then
    echo "Tag '$Tag' removed from keypair '$keypair_name'."
  else
    echo "Failed to remove Tag '$Tag' from keypair '$keypair_name'."
  fi
else
  echo "No keypair found with Tag '$Tag'."
fi

# Check and remove floating IP addresses
floating_ips=$(openstack floating ip list -f value -c ID)
if [ -n "$floating_ips" ]; then
  while read -r floating_ip; do
    openstack floating ip delete "$floating_ip"
    if [ $? -eq 0 ]; then
      echo "Floating IP '$floating_ip' deleted."
    else
      echo "Failed to delete floating IP '$floating_ip'."
    fi
  done <<< "$floating_ips"
else
  echo "No floating IP addresses found."
fi

# Delete servers with names starting with the Tag
server_names=$(openstack server list --name "^${Tag}*" -f value -c Name)
if [ -n "$server_names" ]; then
  while read -r server_name; do
    openstack server delete "$server_name"
    if [ $? -eq 0 ]; then
      echo "Server '$server_name' deleted."
    else
      echo "Failed to delete server '$server_name'."
    fi
  done <<< "$server_names"
else
  echo "No servers found with names starting with '$Tag'."
fi

# Check if the router exists
openstack router show "$router_name" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  subnet_name="${Tag}_subnet"

  # Disconnect subnet from router
  openstack router remove subnet "$router_name" "$subnet_name"
  if [ $? -eq 0 ]; then
    echo "Subnet '$subnet_name' disconnected from router '$router_name'."
  else
    echo "Failed to disconnect subnet '$subnet_name' from router '$router_name'."
    exit 1
  fi

  # Delete the subnet
  openstack subnet delete "$subnet_name"
  if [ $? -eq 0 ]; then
    echo "Subnet '$subnet_name' deleted."
  else
    echo "Failed to delete subnet '$subnet_name'."
  fi

  # Delete the router
  openstack router delete "$router_name"
  if [ $? -eq 0 ]; then
    echo "Router '$router_name' deleted."
  else
    echo "Failed to delete router '$router_name'."
  fi
else
  echo "Router '$router_name' not found."
fi

# Delete the network
network_name="${Tag}_network"
openstack network delete "$network_name" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "Network '$network_name' deleted."
else
  echo "Failed to delete network '$network_name' or network not found."
fi

# Check if there are any networks remaining
remaining_networks=$(openstack network list --Tags "$Tag" -f value -c ID)
if [ -z "$remaining_networks" ]; then
  echo "No networks found with Tag '$Tag'."
fi
