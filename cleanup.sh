#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <Tag>"
  exit 1
fi

Tag="$2"
RouterName="${Tag}_router"


KeypairName=$(openstack keypair list  -f value -c Name | grep $Tag)
if [ -n "$KeypairName" ]; then
  
  openstack keypair delete "$KeypairName"
  if [ $? -eq 0 ]; then
    echo "Tag '$Tag' removed from keypair '$KeypairName'."
  else
    echo "Failed to remove Tag '$Tag' from keypair '$KeypairName'."
  fi
else
  echo "No keypair found with Tag '$Tag'."
fi


FloatingIps=$(openstack floating ip list -f value -c ID)
if [ -n "$FloatingIps" ]; then
  while read -r floating_ip; do
    openstack floating ip delete "$floating_ip"
    if [ $? -eq 0 ]; then
      echo "Floating IP '$floating_ip' deleted."
    else
      echo "Failed to delete floating IP '$floating_ip'."
    fi
  done <<< "$FloatingIps"
else
  echo "No floating IP addresses found."
fi


ServerNames=$(openstack server list --name "^${Tag}*" -f value -c Name)
if [ -n "$ServerNames" ]; then
  while read -r server_name; do
    openstack server delete "$server_name"
    if [ $? -eq 0 ]; then
      echo "Server '$server_name' deleted."
    else
      echo "Failed to delete server '$server_name'."
    fi
  done <<< "$ServerNames"
else
  echo "No servers found with names starting with '$Tag'."
fi

openstack router show "$RouterName" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  
  subnet_name="${Tag}_subnet"


  openstack router remove subnet "$RouterName" "$subnet_name"
  if [ $? -eq 0 ]; then
    echo "Subnet '$subnet_name' disconnected from router '$RouterName'."
  else
    echo "Failed to disconnect subnet '$subnet_name' from router '$RouterName'."
    exit 1
  fi


  openstack subnet delete "$subnet_name"
  if [ $? -eq 0 ]; then
    echo "Subnet '$subnet_name' deleted."
  else
    echo "Failed to delete subnet '$subnet_name'."
  fi


  openstack router delete "$RouterName"
  if [ $? -eq 0 ]; then
    echo "Router '$RouterName' deleted."
  else
    echo "Failed to delete router '$RouterName'."
  fi
else
  echo "Router '$RouterName' not found."
fi


NetworkName="${Tag}_network"
openstack network delete "$NetworkName" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "Network '$NetworkName' deleted."
else
  echo "Failed to delete network '$NetworkName' or network not found."
fi


RemainingNetworks=$(openstack network list --Tags "$Tag" -f value -c ID)
if [ -z "$RemainingNetworks" ]; then
  echo "No networks found with this Tag '$Tag'."
fi

