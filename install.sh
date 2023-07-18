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
# Naming conventions for resources based on the provided tag
KeyName="${tag}_key"
SubnetName="${tag}_subnet"
RouterName="${tag}_router"
ServerName="${tag}_bastion"
ProxyServerName="${tag}_proxy"
SecurityGroup="default"

# Image and flavor details for server creation
#buntu 22.04 Jammy Jellyfish x86_64
image_name="19a8117d-39d6-40d2-bfbf-bc6d4d36adf8"
#1C-2GB
flavor="b78dbffc-e512-4d87-a412-a971c6c5487d "
# Source the OpenStack environment variables from the provided OpenRC file
source "$openrc_file"

# Check if an external network is available in the OpenStack environment
external_net=$(openstack network list --external --format value -c ID)
if [ -z "$external_net" ]; then
    echo "No external network found. Exiting."
    exit 1
fi

# Check if floating IP addresses are available, and if not, create two new ones
floating_ips=$(openstack floating ip list -f value -c "Floating IP Address" )
     echo "Floating IP list is $floating_ips"
floating_num=$(openstack floating ip list -f value -c "Floating IP Address" | wc -l )
     

if [[ floating_num -ge 1 ]]; then
# Use the second available floating IP for the proxy server
    floating_ip_bastion=$(echo "$floating_ips" | awk 'NR==1')
    echo "floating_ip_bastion $floating_ip_bastion"
    
    
    if [[ floating_num -ge 2 ]]; then
    # Use the first available floating IP for the Bastion server
        floating_ip_proxy=$(echo "$floating_ips" | awk 'NR==2')
        echo "floating_ip_proxy $floating_ip_proxy"
    else
         # Create a new floating IP address for the proxy server
        floating_ip_proxy=$(openstack floating ip create  $external_net)
        echo "Created new floating IP for Proxy server: $floating_ip_proxy"
    fi
else
   # Create new floating IP addresses
    echo "creating floating IP"
    floating_ip_1=$(openstack floating ip create  $external_net ) 
    floating_ip_2=$(openstack floating ip create  $external_net)
     echo "Created two new floating IPs: $floating_ip_1, $floating_ip_2"
fi

# Check if the network with the specified tag already exists, and create if not
network_exists=$(openstack network show -f value -c name "$network_name" 2>/dev/null)
if [ -n "$network_exists" ]; then
    echo "A network with the tag '$tag' already exists: $network_name"
else
    # Create the network
    openstack network create "$network_name" --tag "$tag"
    echo "Network created with the tag '$tag': $network_name"
fi

# Check if the key with the specified tag already exists, and create if not
key_exists=$(openstack keypair list --format value --column Name | grep "^$KeyName$")
if [ -n "$key_exists" ]; then
    echo "The key with the name '$KeyName' already exists. Skipping key creation."
else
# Create the keypair
    openstack keypair create --public-key "$public_key" "$KeyName"
    echo "Key created with the name '$KeyName'"
fi
# Check if the subnet with the specified tag already exists, and create if not
subnet_exists=$(openstack subnet show -f value -c name "$SubnetName" 2>/dev/null)
if [ -n "$subnet_exists" ]; then
    echo "The subnet with the name '$SubnetName' already exists. Skipping subnet creation."
else
    #Create the subnet
    openstack subnet create --network "$network_name" --dhcp --ip-version 4 \
        --subnet-range 10.0.0.0/24 --allocation-pool start=10.0.0.100,end=10.0.0.200 \
        --dns-nameserver 1.1.1.1 "$SubnetName"
    echo "Subnet created with the name '$SubnetName'"
fi

# Checking if the router with the specified tag already exists, and create if not
router_exists=$(openstack router show -f value -c name "$RouterName" 2>/dev/null)
if [ -n "$router_exists" ]; then
    echo "The router with the name '$RouterName' already exists. Skipping router creation."
else
    # Create the router
    openstack router create "$RouterName" --tag "$tag" --external-gateway "$external_net"
    echo "Router created with the tag '$tag': $RouterName"
fi

# Add the subnet to the router
openstack router add subnet "$RouterName" "$SubnetName"
echo "Subnet '$SubnetName' added to router '$RouterName'"

# Check if the Bastion server with the specified tag already exists, and create if not
server_exists=$(openstack server show -f value -c name "$ServerName" 2>/dev/null)
if [ -n "$server_exists" ]; then
    echo "The Bastion server with the tag '$tag' already exists: $ServerName"
else
 
    openstack server create --flavor "$flavor" --image "$image_name" --network "$network_name" \
        --security-group "$SecurityGroup" --key-name "$KeyName" "$ServerName"
    echo "Server created with the name '$ServerName'"
fi

# Check if the Proxy server with the specified tag already exists, and create if not
proxy_server_exists=$(openstack server show -f value -c name "$ProxyServerName" 2>/dev/null)
if [ -n "$proxy_server_exists" ]; then
    echo "The proxy server with the tag '$tag' already exists: $ProxyServerName"
else
# Create the Proxy server instance with the same configuration as the Bastion server
    openstack server create --flavor "$flavor" --image "$image_name" --network "$network_name" \
        --security-group "$SecurityGroup" --key-name "$KeyName" "$ProxyServerName"
    echo "Proxy server created with the name '$ProxyServerName'"
fi

# Check if the Node1 ans Node2 and Node3 servers with the specified tag already exists, and create if not

Node1_server_exists=$(openstack server show -f value -c name "${tag}_Node1" 2>/dev/null)
if [ -n "$Node1_server_exists" ]; then
    echo "The Node1 server with the tag '$tag' already exists: ${tag}_Node1"
else
 # Create the Node1 server instance with the same configuration as the previous servers
    openstack server create --flavor "$flavor" --image "$image_name" --network "$network_name" \
        --security-group "$SecurityGroup" --key-name "$KeyName" "${tag}_Node1"
    echo "Node1 server created with the name '${tag}_Node1'"
fi



Node2_server_exists=$(openstack server show -f value -c name "${tag}_Node2" 2>/dev/null)
if [ -n "$Node2_server_exists" ]; then
    echo "The Node2 server with the tag '$tag' already exists: ${tag}_Node2"
else
# Create the Node2 server instance with the same configuration as the previous servers
    openstack server create --flavor "$flavor" --image "$image_name" --network "$network_name" \
        --security-group "$SecurityGroup" --key-name "$KeyName" "${tag}_Node2"
    echo "Node2 server created with the name '${tag}_Node2'"
fi



Node3_server_exists=$(openstack server show -f value -c name "${tag}_Node3" 2>/dev/null)
if [ -n "$Node3_server_exists" ]; then
    echo "The Node3 server with the tag '$tag' already exists: ${tag}_Node3"
else
    # Create the Node3 server instance with the same configuration as the previous servers
    openstack server create --flavor "$flavor" --image "$image_name" --network "$network_name" \
        --security-group "$SecurityGroup" --key-name "$KeyName" "${tag}_Node3"
    echo "Node3 server created with the name '${tag}_Node3'"
fi

bastion_ip=$(openstack server show -f value -c addresses $ServerName | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
echo " IP bastion = '$bastion_ip'"
proxy_ip=$(openstack server show -f value -c addresses $ProxyServerName | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
echo " IP proxy = '$proxy_ip'"

Node1_ip=$(openstack server show -f value -c addresses "${tag}_Node1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
echo " IP Node1 = '$Node1_ip'"
Node2_ip=$(openstack server show -f value -c addresses "${tag}_Node2" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
echo " IP Node2 = '$Node2_ip'"
Node3_ip=$(openstack server show -f value -c addresses "${tag}_Node3" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
echo " IP Node3 = '$Node3_ip'"

floating_ips=$(openstack floating ip list -f value -c "Floating IP Address" )
floating_ip_bastion=$(echo "$floating_ips" | awk 'NR==1')
echo "floating_ip_bastion $floating_ip_bastion"
floating_ip_proxy=$(echo "$floating_ips" | awk 'NR==2')
echo "floating_ip_proxy $floating_ip_proxy"


# Assign the floating IPs to the servers
openstack server add floating ip $ServerName $floating_ip_bastion
openstack server add floating ip $ProxyServerName $floating_ip_proxy
echo "Assigned floating IP $floating_ip_bastion to server $ServerName"
echo "Assigned floating IP $floating_ip_proxy to server $ProxyServerName"

# Build base SSH config file for easy access to the servers
ssh_config_file="SSH-config"

echo "# SSH configuration for ${tag}_Node1" > "$ssh_config_file"
echo "Host ${tag}_Node1" >> "$ssh_config_file"
echo "  HostName $Node1_ip" >> "$ssh_config_file"
echo "  User ubuntu" >> "$ssh_config_file"
echo " StrictHostKeyChecking no" >> "$ssh_config_file"
echo "  IdentityFile ~/.ssh/id_rsa" >> "$ssh_config_file"
echo "" >> "$ssh_config_file"

echo "# SSH configuration for ${tag}_Node2" >> "$ssh_config_file"
echo "Host ${tag}_Node2" >> "$ssh_config_file"
echo "  HostName $Node2_ip" >> "$ssh_config_file"
echo "  User ubuntu" >> "$ssh_config_file"
echo " StrictHostKeyChecking no" >> "$ssh_config_file"
echo "  IdentityFile ~/.ssh/id_rsa" >> "$ssh_config_file"
echo "" >> "$ssh_config_file"

echo "# SSH configuration for ${tag}_Node3" >> "$ssh_config_file"
echo "Host ${tag}_Node3" >> "$ssh_config_file"
echo "  HostName $Node3_ip" >> "$ssh_config_file"
echo "  User ubuntu" >> "$ssh_config_file"
echo " StrictHostKeyChecking no" >> "$ssh_config_file"
echo "  IdentityFile ~/.ssh/id_rsa" >> "$ssh_config_file"
echo "" >> "$ssh_config_file"

echo "# SSH configuration for ${tag}_proxy" >> "$ssh_config_file"
echo "Host ${tag}_proxy" >> "$ssh_config_file"
echo "  HostName $proxy_ip" >> "$ssh_config_file"
echo "  User ubuntu" >> "$ssh_config_file"
echo " StrictHostKeyChecking no" >> "$ssh_config_file"
echo "  IdentityFile ~/.ssh/id_rsa" >> "$ssh_config_file"

echo "Base SSH configuration file created: $ssh_config_file"

# Install Ansible on the Bastion server and run a playbook
echo "Install ansible"
ssh -o StrictHostKeyChecking=no -i id_rsa.pub ubuntu@$floating_ip_bastion 'sudo apt update >/dev/null 2>&1 && sudo apt install -y ansible >/dev/null 2>&1'
# Checking the Ansible version of host
ansible_version=$(ssh -i id_rsa.pub ubuntu@$floating_ip_bastion 'ansible --version')
echo "Ansible installed successfully"
echo "Ansible version: $ansible_version"

# Copy the public key, SSH config file, and Ansible playbook to the Bastion server
echo "Copying public key to the Bastion server"
scp  -o StrictHostKeyChecking=no id_rsa.pub ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes id_rsa ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes  $ssh_config_file ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes  -r ansible ubuntu@$floating_ip_bastion:~/.ssh
# Run the Ansible playbook on the Bastion server
ssh -i id_rsa.pub ubuntu@$floating_ip_bastion "ansible-playbook -i ~/.ssh/ansible/hosts ~/.ssh/ansible/site.yaml "

















