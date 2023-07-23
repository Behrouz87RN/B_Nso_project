#!/bin/bash

# Ensure a tag argument is provided
if [ -z "$1" ] || [ -z "$2" ] ; then
  echo "Please provide Usage:$1 <openrc> $2 <tag>"
  exit 1
fi

# Retrieve the specified tag
openrc_file="$1"
tag="$2"
# Identify the corresponding router name based on the tag
router_name="${tag}_router"

source "$openrc_file"

# Discover the keypair name associated with the given tag
keypair_name=$(openstack keypair list -f value -c Name | grep $tag)
if [ -n "$keypair_name" ]; then
  openstack keypair delete "$keypair_name"
  if [ $? -eq 0 ]; then
    echo "tag '$tag' removed from keypair '$keypair_name'."
  else
    echo "Failed to remove tag '$tag' from keypair '$keypair_name'."
  fi
else
  echo "No keypair found with tag '$tag'."
fi

# Remove floating IP addresses
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

# Delete servers with names starting with the specified tag
server_names=$(openstack server list --name "^${tag}*" -f value -c Name)
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
  echo "No servers found with names starting with '$tag'."
fi

# Verify if the router exists
openstack router show "$router_name" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  subnet_name="${tag}_subnet"

  # Disconnect subnet from router
  openstack router remove subnet "$router_name" "$subnet_name"
  if [ $? -eq 0 ]; then
    echo "Subnet '$subnet_name' disconnected from router '$router_name'."
  else
    echo "Failed to disconnect subnet '$subnet_name' from router '$router_name'."
    exit 1
  fi

  # Delete  subnets
  openstack subnet delete "$subnet_name"
  if [ $? -eq 0 ]; then
    echo "Subnet '$subnet_name' deleted."
  else
    echo "Failed to delete subnet '$subnet_name'."
  fi

  # Delete routers
  openstack router delete "$router_name"
  if [ $? -eq 0 ]; then
    echo "Router '$router_name' deleted."
  else
    echo "Failed to delete router '$router_name'."
  fi
else
  echo "Router '$router_name' not found."
fi

# Delete  networks
network_name="${tag}_network"
openstack network delete "$network_name" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "Network '$network_name' deleted."
else
  echo "Failed to delete network '$network_name' or network not found."
fi

# Check if there are any remaining networks
remaining_networks=$(openstack network list --tags "$tag" -f value -c ID)
if [ -z "$remaining_networks" ]; then
  echo "No networks found with tag '$tag'."
fi

