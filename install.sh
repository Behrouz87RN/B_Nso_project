#!/bin/bash


if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Please provide the path to the openrc file, tag, and public key as command-line arguments."
    exit 1
fi

openrc_file="$1"
tag="$2"
public_key="$3"
network_name="${tag}_network"

KeyName="${tag}_key"
SubnetName="${tag}_subnet"
RouterName="${tag}_router"
ServerName="${tag}_bastion"
proxy_ServerName="${tag}_proxy"
security_group="default"


image_name="c8b13dfa-10aa-4473-8302-2206dcf7f9b4"
flavor="1C-1GB"

source "$openrc_file"


external_net=$(openstack network list --external --format value -c ID)
if [ -z "$external_net" ]; then
    echo "No external network found. Exiting."
    exit 1
fi


floating_ips=$(openstack floating ip list -f value -c "Floating IP Address" )
     echo "Floating IP list is $floating_ips"
floating_num=$(openstack floating ip list -f value -c "Floating IP Address" | wc -l )
     

if [[ floating_num -ge 1 ]]; then

    floating_ip_bastion=$(echo "$floating_ips" | awk 'NR==1')
    echo "floating_ip_bastion $floating_ip_bastion"
    
    
    if [[ floating_num -ge 2 ]]; then
        
        floating_ip_proxy=$(echo "$floating_ips" | awk 'NR==2')
        echo "floating_ip_proxy $floating_ip_proxy"
    else
        
        floating_ip_proxy=$(openstack floating ip create  $external_net)
    fi
else
   
    echo "creating floating IP"
    floating_ip_1=$(openstack floating ip create  $external_net ) 
    floating_ip_2=$(openstack floating ip create  $external_net)
    
fi


network_exists=$(openstack network show -f value -c name "$network_name" 2>/dev/null)
if [ -n "$network_exists" ]; then
    echo "A network with the tag '$tag' already exists: $network_name"
else
    
    openstack network create "$network_name" --tag "$tag"
    echo "Network created with the tag '$tag': $network_name"
fi


key_exists=$(openstack keypair list --format value --column Name | grep "^$KeyName$")
if [ -n "$key_exists" ]; then
    echo "The key with the name '$KeyName' already exists. Skipping key creation."
else

    openstack keypair create --public-key "$public_key" "$KeyName"
    echo "Key created with the name '$KeyName'"
fi

subnet_exists=$(openstack subnet show -f value -c name "$SubnetName" 2>/dev/null)
if [ -n "$subnet_exists" ]; then
    echo "The subnet with the name '$SubnetName' already exists. Skipping subnet creation."
else
    
    openstack subnet create --network "$network_name" --dhcp --ip-version 4 \
        --subnet-range 10.0.0.0/24 --allocation-pool start=10.0.0.100,end=10.0.0.200 \
        --dns-nameserver 1.1.1.1 "$SubnetName"
    echo "Subnet created with the name '$SubnetName'"
fi


router_exists=$(openstack router show -f value -c name "$RouterName" 2>/dev/null)
if [ -n "$router_exists" ]; then
    echo "The router with the name '$RouterName' already exists. Skipping router creation."
else
    
    openstack router create "$RouterName" --tag "$tag" --external-gateway "$external_net"
    echo "Router created with the tag '$tag': $RouterName"
fi


openstack router add subnet "$RouterName" "$SubnetName"
echo "Subnet '$SubnetName' added to router '$RouterName'"






server_exists=$(openstack server show -f value -c name "$ServerName" 2>/dev/null)
if [ -n "$server_exists" ]; then
    echo "The Bastion server with the tag '$tag' already exists: $ServerName"
else
 
    openstack server create --flavor "$flavor" --image "$image_name" --network "$network_name" \
    --security-group "$security_group" --key-name "$KeyName" "$ServerName"
    echo "Server created with the name '$ServerName'"
fi


proxy_server_exists=$(openstack server show -f value -c name "$proxy_ServerName" 2>/dev/null)
if [ -n "$proxy_server_exists" ]; then
    echo "The proxy server with the tag '$tag' already exists: $proxy_ServerName"
else

    openstack server create --flavor "$flavor" --image "$image_id" --network "$network_name" \
        --security-group "$security_group" --key-name "$KeyName" "$proxy_ServerName"
    echo "Proxy server created with the name '$proxy_ServerName'"
fi



deva_server_exists=$(openstack server show -f value -c name "${tag}_deva" 2>/dev/null)
if [ -n "$deva_server_exists" ]; then
    echo "The deva server with the tag '$tag' already exists: ${tag}_deva"
else
 
    openstack server create --flavor "$flavor" --image "$image_id" --network "$network_name" \
        --security-group "$security_group" --key-name "$KeyName" "${tag}_deva"
    echo "Deva server created with the name '${tag}_deva'"
fi



devb_server_exists=$(openstack server show -f value -c name "${tag}_devb" 2>/dev/null)
if [ -n "$devb_server_exists" ]; then
    echo "The devb server with the tag '$tag' already exists: ${tag}_devb"
else

    openstack server create --flavor "$flavor" --image "$image_id" --network "$network_name" \
        --security-group "$security_group" --key-name "$KeyName" "${tag}_devb"
    echo "Devb server created with the name '${tag}_devb'"
fi



devc_server_exists=$(openstack server show -f value -c name "${tag}_devc" 2>/dev/null)
if [ -n "$devc_server_exists" ]; then
    echo "The devc server with the tag '$tag' already exists: ${tag}_devc"
else
    
    openstack server create --flavor "$flavor" --image "$image_id" --network "$network_name" \
        --security-group "$security_group" --key-name "$KeyName" "${tag}_devc"
    echo "Devc server created with the name '${tag}_devc'"
fi

bastion_ip=$(openstack server show -f value -c addresses $ServerName | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
echo " IP bastion = '$bastion_ip'"
proxy_ip=$(openstack server show -f value -c addresses $proxy_server_name | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
echo " IP proxy = '$proxy_ip'"

deva_ip=$(openstack server show -f value -c addresses "${tag}_deva" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
echo " IP deva = '$deva_ip'"
devb_ip=$(openstack server show -f value -c addresses "${tag}_devb" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
echo " IP devb = '$devb_ip'"
devc_ip=$(openstack server show -f value -c addresses "${tag}_devc" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
echo " IP devc = '$devc_ip'"

floating_ips=$(openstack floating ip list -f value -c "Floating IP Address" )
floating_ip_bastion=$(echo "$floating_ips" | awk 'NR==1')
echo "floating_ip_bastion $floating_ip_bastion"
floating_ip_proxy=$(echo "$floating_ips" | awk 'NR==2')
echo "floating_ip_proxy $floating_ip_proxy"



openstack server add floating ip $ServerName $floating_ip_bastion
openstack server add floating ip $proxy_server_name $floating_ip_proxy
echo "Assigned floating IP $floating_ip_bastion to server $ServerName"
echo "Assigned floating IP $floating_ip_proxy to server $proxy_server_name"


ssh_config_file="SSH-config"

echo "# SSH configuration for ${tag}_deva" > "$ssh_config_file"
echo "Host ${tag}_deva" >> "$ssh_config_file"
echo "  HostName $deva_ip" >> "$ssh_config_file"
echo "  User ubuntu" >> "$ssh_config_file"
echo " StrictHostKeyChecking no" >> "$ssh_config_file"
echo "  IdentityFile ~/.ssh/id_rsa" >> "$ssh_config_file"
echo "" >> "$ssh_config_file"

echo "# SSH configuration for ${tag}_devb" >> "$ssh_config_file"
echo "Host ${tag}_devb" >> "$ssh_config_file"
echo "  HostName $devb_ip" >> "$ssh_config_file"
echo "  User ubuntu" >> "$ssh_config_file"
echo " StrictHostKeyChecking no" >> "$ssh_config_file"
echo "  IdentityFile ~/.ssh/id_rsa" >> "$ssh_config_file"
echo "" >> "$ssh_config_file"

echo "# SSH configuration for ${tag}_devc" >> "$ssh_config_file"
echo "Host ${tag}_devc" >> "$ssh_config_file"
echo "  HostName $devc_ip" >> "$ssh_config_file"
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


echo "Install ansible"
ssh -o StrictHostKeyChecking=no -i id_rsa.pub ubuntu@$floating_ip_bastion 'sudo apt update >/dev/null 2>&1 && sudo apt install -y ansible >/dev/null 2>&1'

ansible_version=$(ssh -i id_rsa.pub ubuntu@$floating_ip_bastion 'ansible --version')
echo "Ansible installed successfully"
echo "Ansible version: $ansible_version"


echo "Copying public key to the Bastion server"
scp  -o StrictHostKeyChecking=no id_rsa.pub ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes id_rsa ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes  $ssh_config_file ubuntu@$floating_ip_bastion:~/.ssh
scp  -o BatchMode=yes  -r ansible ubuntu@$floating_ip_bastion:~/.ssh

ssh -i id_rsa.pub ubuntu@$floating_ip_bastion "ansible-playbook -i ~/.ssh/ansible/hosts ~/.ssh/ansible/site.yaml "

















