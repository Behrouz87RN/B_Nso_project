#!/bin/bash

# Check if all required command-line arguments are provided
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Please provide the path to the openrc file, tag, and public key as command-line arguments."
    exit 1
fi
# Read the command-line arguments
openrc_file="$1"
tag="$2"
PublicKey="$3"
NetworkName="${tag}_network"
# Naming conventions for resources based on the provided tag
KeyName="${tag}_key"
SubnetName="${tag}_subnet"
RouterName="${tag}_router"
ServerName="${tag}_bastion"
ProxyServerName="${tag}_proxy"
SecurityGroup="default"
image_name="Ubuntu 20.04"
flavor="1C-2GB"


#sto2
#Ubuntu 20.04 Focal Fossa x86_64 
#image_name=" b094d71d-41a3-4faf-a0e7-d18d0c0db9e6"
#buntu 22.04 Jammy Jellyfish x86_64
#image_name="19a8117d-39d6-40d2-bfbf-bc6d4d36adf8"
#1C-2GB
#flavor="b78dbffc-e512-4d87-a412-a971c6c5487d "

#kna1
#buntu 22.04 Jammy Jellyfish x86_64
#image_name="c8b13dfa-10aa-4473-8302-2206dcf7f9b4"
#1C-2GB
#flavor="fbe75bd2-6042-4c71-8c49-944b29e9d455"



# Source the OpenStack environment variables from the provided OpenRC file
source "$openrc_file"
echo "$(date '+%Y-%m-%d %H:%M:%S') Starting deployment of $tag using $openrc_file for credentials."
#echo  "Starting deployment of $tag using $openrc_file for credential"
echo "$(date '+%Y-%m-%d %H:%M:%S') Detecting suitable image, looking for Ubuntu 20.0"
# Find the image ID for Ubuntu 20.04
image=$(openstack image list --format value | grep "$image_name")
# Check if image is empty
if [[ -z "$image" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Image  Ubuntu 20.04 not found: $image_name"
else
    image_id=$(echo "$image" | awk '{print $1}')
    #echo "Image found: $image"
    echo "$(date '+%Y-%m-%d %H:%M:%S') Image Ubuntu 20.04 with ID : $image_id exist. "
fi


# Check if an external network is available in the OpenStack environment
external_net=$(openstack network list --external --format value -c ID )
if [ -z "$external_net" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') No external network found. Exiting."
    exit 1
fi

# Check if floating IP addresses are available, and if not, create two new ones

floating_ips=$(openstack floating ip list -f value -c "Floating IP Address" )
#te '+%Y-%m-%d %H:%M:%S')Checking if we have floating IPs availible, we have 0 availible."
#     echo "Floating IP list is $floating_ips"
floating_num=$(openstack floating ip list -f value -c "Floating IP Address" | wc -l )
if [[ floating_num -ge 1 ]]; then
# Use the second available floating IP for the proxy server
    floating_ip_bastion=$(echo "$floating_ips" | awk 'NR==1')
    echo "$(date '+%Y-%m-%d %H:%M:%S') floating_ip_bastion $floating_ip_bastion"
    
    
    if [[ floating_num -ge 2 ]]; then
    # Use the first available floating IP for the Bastion server
        floating_ip_proxy=$(echo "$floating_ips" | awk 'NR==2')
        echo "$(date '+%Y-%m-%d %H:%M:%S') floating_ip_proxy $floating_ip_proxy"
    else
         # Create a new floating IP address for the proxy server
        floating_ip_proxy=$(openstack floating ip create  "$external_net" >/dev/null 2>&1)
        echo "$(date '+%Y-%m-%d %H:%M:%S') Created new floating IP for Proxy server: $floating_ip_proxy"
    fi
else
   # Create new floating IP addresses
    echo "$(date '+%Y-%m-%d %H:%M:%S') creating floating IPs"
    floating_ip_1=$(openstack floating ip create "$external_net" 1>/dev/null)
    floating_ip_2=$(openstack floating ip create "$external_net"  1>/dev/null )
    #echo "Created two new floating IPs: $floating_ip_1 , $floating_ip_2"
    echo  "$(date '+%Y-%m-%d %H:%M:%S') Allocating floating IP 1, 2. Done"
fi

# Check if the network with the specified tag already exists, and create if not
network_exists=$(openstack network show -f value -c name "$NetworkName"  )
if [ -n "$network_exists" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') A network already exists: $NetworkName"
else
    # Create the network
    openstack network create "$NetworkName" --tag "$tag" 1>/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') Network created with the tag '$tag': $NetworkName"
fi

# Check if the key with the specified tag already exists, and create if not
key_exists=$(openstack keypair list --format value --column Name | grep "^$KeyName$" )
if [ -n "$key_exists" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') The key with the name '$KeyName' already exists. Skipping key creation."
else
# Create the keypair
    openstack keypair create --public-key "$PublicKey" "$KeyName" 1>/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') Key created with the name '$KeyName'"
fi
# Check if the subnet with the specified tag already exists, and create if not
subnet_exists=$(openstack subnet show -f value -c name "$SubnetName" )
if [ -n "$subnet_exists" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') The subnet with the name '$SubnetName' already exists. Skipping subnet creation."
else
    #Create the subnet
    openstack subnet create --network "$NetworkName" --dhcp --ip-version 4 \
        --subnet-range 10.0.0.0/24 --allocation-pool start=10.0.0.50,end=10.0.0.150 \
        --dns-nameserver 1.1.1.1 "$SubnetName" 1>/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') Subnet created with the name '$SubnetName'"
fi

# Checking if the router with the specified tag already exists, and create if not
router_exists=$(openstack router show -f value -c name "$RouterName" )
if [ -n "$router_exists" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') The router with the name '$RouterName' already exists. Skipping router creation."
else
    # Create the router
    openstack router create "$RouterName" --tag "$tag" --external-gateway "$external_net" 1>/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') Router created with the tag '$tag': $RouterName"
fi



# Check if the subnet is already attached to the router
subnet_attached=$(openstack port list --router "$RouterName" --fixed-ip subnet="$SubnetName" -f value -c ID)

if [ -n "$subnet_attached" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') The router with the name '$RouterName' already has a subnet attached."
else
    # Add the subnet to the router
    openstack router add subnet "$RouterName" "$SubnetName" 1>/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') Subnet '$SubnetName' added to router '$RouterName'"
fi


# # Add the subnet to the router
# openstack router add subnet "$RouterName" "$SubnetName"
# echo "$(date '+%Y-%m-%d %H:%M:%S')Subnet '$SubnetName' added to router '$RouterName'"


# Check if the Bastion server with the specified tag already exists, and create if not
server_exists=$(openstack server show -f value -c name "$ServerName" )
if [ -n "$server_exists" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') The Bastion server with the tag '$tag' already exists: $ServerName"
else

    openstack server create --flavor "$flavor" --image "$image_id" --network "$NetworkName" \
        --security-group "$SecurityGroup" --key-name "$KeyName" "$ServerName" 1>/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') Server created with the name '$ServerName'"
fi

# Check if the Proxy server with the specified tag already exists, and create if not
proxy_server_exists=$(openstack server show -f value -c name "$ProxyServerName" )
if [ -n "$proxy_server_exists" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') The proxy server with the tag '$tag' already exists: $ProxyServerName"
else
# Create the Proxy server instance with the same configuration as the Bastion server
    openstack server create --flavor "$flavor" --image "$image_id" --network "$NetworkName" \
        --security-group "$SecurityGroup" --key-name "$KeyName" "$ProxyServerName" 1>/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') Proxy server created with the name '$ProxyServerName'"
fi


# Read the number of nodes from server.conf
server_conf="server.conf"
num_nodes=$(grep -i "num_nodes" "$server_conf" | awk -F "=" '{print $2}' | tr -d ' ')

# Check if the Node servers with the specified tag already exist, and create if not
for ((i = 1; i <= num_nodes; i++)); do
    Node_server_exists=$(openstack server show -f value -c name "${tag}_Node$i" )
    if [ -n "$Node_server_exists" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') The Node$i server with the tag '$tag' already exists: ${tag}_Node$i"
    else
        # Create the Node$i server instance with the same configuration as the previous servers
        openstack server create --flavor "$flavor" --image "$image_id" --network "$NetworkName" \
            --security-group "$SecurityGroup" --key-name "$KeyName" "${tag}_Node$i" 1>/dev/null
        echo "$(date '+%Y-%m-%d %H:%M:%S') Node$i server created with the name '${tag}_Node$i'"
    fi
done

# Generate hosts file
hosts_file="hosts"
echo "[haproxy]" > "$hosts_file"
echo "${tag}_proxy" >> "$hosts_file"
echo "" >> "$hosts_file"
echo "[webservers]" >> "$hosts_file"
for ((i=1; i <= $num_nodes; i++)); do
    echo "${tag}_Node$i" >> "$hosts_file"
done
echo "" >> "$hosts_file"
echo "[all:vars]" >> "$hosts_file"
echo "ansible_user=ubuntu" >> "$hosts_file"
echo "ansible_ssh_private_key_file=/.ssh/id_rsa.pub" >> "$hosts_file"
# Print a message indicating the hosts file has been created
echo "$(date '+%Y-%m-%d %H:%M:%S') Host configuration file created: $hosts_file"




bastion_ip=$(openstack server show -f value -c addresses $ServerName | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
echo "$(date '+%Y-%m-%d %H:%M:%S') IP bastion = '$bastion_ip'"
proxy_ip=$(openstack server show -f value -c addresses $ProxyServerName | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
echo "$(date '+%Y-%m-%d %H:%M:%S') IP proxy = '$proxy_ip'"

# Node1_ip=$(openstack server show -f value -c addresses "${tag}_Node1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
# echo " IP Node1 = '$Node1_ip'"
# Node2_ip=$(openstack server show -f value -c addresses "${tag}_Node2" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
# echo " IP Node2 = '$Node2_ip'"
# Node3_ip=$(openstack server show -f value -c addresses "${tag}_Node3" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
# echo " IP Node3 = '$Node3_ip'"


# Loop through the number of nodes and set the IP addresses
for ((i = 1; i <= num_nodes; i++)); do
    node_name="Node${i}"
    Node_ip=$(openstack server show -f value -c addresses "${tag}_${node_name}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    echo "$(date '+%Y-%m-%d %H:%M:%S') IP $node_name = '$Node_ip'"
done



floating_ips=$(openstack floating ip list -f value -c "Floating IP Address" )
floating_ip_bastion=$(echo "$floating_ips" | awk 'NR==1')
echo "$(date '+%Y-%m-%d %H:%M:%S') floating_ip_bastion $floating_ip_bastion"
floating_ip_proxy=$(echo "$floating_ips" | awk 'NR==2')
echo "$(date '+%Y-%m-%d %H:%M:%S') floating_ip_proxy $floating_ip_proxy"


# Assign the floating IPs to the servers
openstack server add floating ip $ServerName $floating_ip_bastion
openstack server add floating ip $ProxyServerName $floating_ip_proxy
echo "$(date '+%Y-%m-%d %H:%M:%S') Assigned floating IP $floating_ip_bastion to server $ServerName"
echo "$(date '+%Y-%m-%d %H:%M:%S') Assigned floating IP $floating_ip_proxy to server $ProxyServerName"

# Build base SSH config file for easy access to the servers
#ssh_config_file="config"

# echo "# SSH configuration for ${tag}_Node1" > "$ssh_config_file"
# echo "Host ${tag}_Node1" >> "$ssh_config_file"
# echo "  HostName $Node1_ip" >> "$ssh_config_file"
# echo "  User ubuntu" >> "$ssh_config_file"
# echo " StrictHostKeyChecking no" >> "$ssh_config_file"
# echo "  IdentityFile ~/.ssh/id_rsa" >> "$ssh_config_file"
# echo "" >> "$ssh_config_file"

# echo "# SSH configuration for ${tag}_Node2" >> "$ssh_config_file"
# echo "Host ${tag}_Node2" >> "$ssh_config_file"
# echo "  HostName $Node2_ip" >> "$ssh_config_file"
# echo "  User ubuntu" >> "$ssh_config_file"
# echo " StrictHostKeyChecking no" >> "$ssh_config_file"
# echo "  IdentityFile ~/.ssh/id_rsa" >> "$ssh_config_file"
# echo "" >> "$ssh_config_file"

# echo "# SSH configuration for ${tag}_Node3" >> "$ssh_config_file"
# echo "Host ${tag}_Node3" >> "$ssh_config_file"
# echo "  HostName $Node3_ip" >> "$ssh_config_file"
# echo "  User ubuntu" >> "$ssh_config_file"
# echo " StrictHostKeyChecking no" >> "$ssh_config_file"
# echo "  IdentityFile ~/.ssh/id_rsa" >> "$ssh_config_file"
# echo "" >> "$ssh_config_file"

# echo "# SSH configuration for ${tag}_proxy" >> "$ssh_config_file"
# echo "Host ${tag}_proxy" >> "$ssh_config_file"
# echo "  HostName $proxy_ip" >> "$ssh_config_file"
# echo "  User ubuntu" >> "$ssh_config_file"
# echo " StrictHostKeyChecking no" >> "$ssh_config_file"
# echo "  IdentityFile ~/.ssh/id_rsa" >> "$ssh_config_file"

# echo "Base SSH configuration file created: $ssh_config_file"



# # Generate SSH configuration file
ssh_config_file="config"
# # Clear the existing content of the SSH config file (optional, uncomment if needed)
> "$ssh_config_file"
for ((i=1; i<= num_nodes; i++)); do
    Node_ip=$(openstack server show -f value -c addresses "${tag}_Node$i" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    echo "# SSH configuration for ${tag}_Node$i" >> "$ssh_config_file"
    echo "Host ${tag}_Node$i" >> "$ssh_config_file"
    echo "  HostName $Node_ip" >> "$ssh_config_file"
    echo "  User ubuntu" >> "$ssh_config_file"
    echo "  StrictHostKeyChecking no" >> "$ssh_config_file"
    echo "  IdentityFile ~/.ssh/id_rsa" >> "$ssh_config_file"
    echo "" >> "$ssh_config_file"
done

echo "# SSH configuration for ${tag}_proxy" >> "$ssh_config_file"
echo "Host ${tag}_proxy" >> "$ssh_config_file"
echo "  HostName $proxy_ip" >> "$ssh_config_file"
echo "  User ubuntu" >> "$ssh_config_file"
echo "  StrictHostKeyChecking no" >> "$ssh_config_file"
echo "  IdentityFile ~/.ssh/id_rsa" >> "$ssh_config_file"

echo "$(date '+%Y-%m-%d %H:%M:%S') Base SSH configuration file created: $ssh_config_file"




# Install Ansible on the Bastion server and run a playbook
echo "$(date '+%Y-%m-%d %H:%M:%S') Install ansible"
ssh -o StrictHostKeyChecking=no -i id_rsa.pub ubuntu@$floating_ip_bastion 'sudo apt update >/dev/null 2>&1 && sudo apt install -y ansible >/dev/null 2>&1'
# Checking the Ansible version of host
ansible_version=$(ssh -i id_rsa.pub ubuntu@$floating_ip_bastion 'ansible --version')
echo "$(date '+%Y-%m-%d %H:%M:%S') Ansible installed successfully"
echo "$(date '+%Y-%m-%d %H:%M:%S') Ansible version: $ansible_version"

# Copy the public key, SSH config file, and Ansible playbook to the Bastion server
echo "$(date '+%Y-%m-%d %H:%M:%S') Copying files and public key to the Bastion server"
scp  -o StrictHostKeyChecking=no id_rsa.pub ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes id_rsa ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes  $ssh_config_file ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes  hosts ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes  site.yaml ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes  server.conf ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes  my_flask_app.service ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes  application2.py ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes  haproxy.cfg.j2 ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes  snmpd.conf ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes  monitoring-config.conf.j2 ubuntu@$floating_ip_bastion:~/.ssh

# Run the Ansible playbook on the Bastion server
ssh -i id_rsa.pub ubuntu@$floating_ip_bastion "ansible-playbook -i ~/.ssh/hosts ~/.ssh/site.yaml "
