#!/bin/bash


formatted_time=$(date +"%Y-%m-%d %H:%M:%S")



cleanup_keypair() {
  keypair_names=$(openstack keypair list -f value -c Name | grep $tag)
  if [ -n "$keypair_names" ]; then
    for keypair_name in $keypair_names; do
      if openstack keypair delete "$keypair_name"; then
        echo "$formatted_time Tag '$tag' removed from keypair '$keypair_name'."
      else
        echo "$formatted_time Failed to remove tag '$tag' from keypair '$keypair_name'."
      fi
    done
  else
    echo "$formatted_time No keypair found with tag '$tag'."
  fi
}


cleanup_floating_ips() {
  floating_ips=$(openstack floating ip list -f value -c ID)
  if [ -n "$floating_ips" ]; then
    while read -r floating_ip; do
      if openstack floating ip delete "$floating_ip"; then
        echo "$formatted_time Floating IP '$floating_ip' deleted."
      else
        echo "$formatted_time Failed to delete floating IP '$floating_ip'."
      fi
    done <<< "$floating_ips"
  else
    echo "$formatted_time No floating IP addresses found."
  fi
}

cleanup_servers() {
  server_names=$(openstack server list --name "^${tag}*" -f value -c Name)
  if [ -n "$server_names" ]; then
    echo "$formatted_time We have $(echo "$server_names" | wc -l) nodes releasing them"
    while read -r server_name; do
      if openstack server delete "$server_name"; then
        echo "$formatted_time Releasing $server_name"
      else
        echo "$formatted_time Failed to release $server_name"
      fi
    done <<< "$server_names"

    # Wait for nodes to disappear
    echo "$formatted_time Waiting for nodes to disappear..."
    sleep 10
    while [ -n "$(openstack server list --name "^${tag}*" -f value -c Name)" ]; do
      sleep 2
    done
    echo "$formatted_time Nodes are gone."
  else
    echo "$formatted_time No servers found with names starting with '$tag'."
  fi
}

cleanup_network() {
  router_name="${tag}_router"
  if openstack router show "$router_name" > /dev/null 2>&1; then
    subnet_name="${tag}_subnet"
    if openstack router remove subnet "$router_name" "$subnet_name"; then
      echo "$formatted_time Removing $subnet_name from $router_name"
    else
      echo "$formatted_time Failed to remove $subnet_name from $router_name"
      exit 1
    fi

    if openstack subnet delete "$subnet_name"; then
      echo "$formatted_time Removing $subnet_name"
    else
      echo "$formatted_time Failed to remove $subnet_name"
    fi

    if openstack router delete "$router_name"; then
      echo "$formatted_time Removing $router_name"
    else
      echo "$formatted_time Failed to remove $router_name"
    fi
  else
    echo "$formatted_time $router_name not found."
  fi

  network_name="${tag}_network"
  if openstack network delete "$network_name" > /dev/null 2>&1; then
    echo "$formatted_time Removing $network_name"
  else
    echo "$formatted_time Failed to remove $network_name or network not found."
  fi

  remaining_networks=$(openstack network list --tags "$tag" -f value -c ID)
  remaining_subnets=$(openstack subnet list --tags "$tag" -f value -c ID)
  remaining_routers=$(openstack router list --tags "$tag" -f value -c ID)
  remaining_keypairs=$(openstack keypair list --tags "$tag" -f value -c ID)

  echo "$formatted_time Checking for $tag in project."
  echo "$formatted_time Remaining resources: (network)($remaining_networks)(subnet)($remaining_subnets)(router)($remaining_routers)(keypairs)($remaining_keypairs)"
}

# Ensure a tag argument is provided
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Please provide Usage: $0 <openrc> <tag>"
  exit 1
fi

# Retrieve the specified tag
openrc_file="$1"
tag="$2"

# Source the OpenRC file to set up the environment variables
source "$openrc_file"

# Perform the resource cleanup
echo "$formatted_time Cleaning up $tag using $openrc_file"
cleanup_keypair
cleanup_floating_ips
cleanup_servers
cleanup_network
echo "$formatted_time Cleanup done."

