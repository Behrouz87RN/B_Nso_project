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
#ServerName="${tag}_bastion"
#ProxyServerName="${tag}_proxy"
SecurityGroup="default"
image_name="Ubuntu 22.04 J"
flavor="1C-2GB"

formatted_time=$(date +"%Y-%m-%d %H:%M:%S")


# Source the OpenStack environment variables from the provided OpenRC file
source "$openrc_file"
echo "$formatted_time Starting Operate of $tag using $openrc_file for credentials."
#echo  "Starting deployment of $tag using $openrc_file for credential"
echo "$formatted_time Detecting suitable image, looking for Ubuntu 22.04 J"
# Find the image ID for Ubuntu 22.04
image=$(openstack image list --format value | grep "$image_name")
# Check if image is empty
if [[ -z "$image" ]]; then
    echo "$formatted_time Image  Ubuntu 22.04 not found: $image_name"
else
    image_id=$(echo "$image" | awk '{print $1}')
    #echo "Image found: $image"
    echo "$formatted_time Image Ubuntu 22.04 with ID : $image_id exist. "
fi

#flask monitoring
# hosts_file="~/.ssh/hosts" # Path to the hosts file
# # Function to extract the node names from hosts file
# get_node_names() {
#     awk '/^\[webservers\]/{f=1; next} /^\[/{f=0} f && NF {print $1}' "$hosts_file"
# }

# # Get the node names
# node_names=$(get_node_names)
# # Create or overwrite the site.yaml file
# cat << EOF > site.yaml
# nodes:
# EOF
# # Append each node name to site.yaml
# for node in $node_names; do
#     echo "  - $node" >> site.yaml
# done
# echo "Nodes written to site.yaml:"
# cat site.yaml


# Read server.conf to get the required number of nodes
config_lines=$(<server.conf)
# Extract the number of nodes required from server.conf
num_nodes=$(echo "$config_lines" | grep -oP 'num_nodes = \K\d+')
if [ -z "$num_nodes" ]; then
    echo "${formatted_time}: Unable to find the required number of nodes in server.conf."
    exit 1
fi
echo "${formatted_time}: Reading server.conf, we need $num_nodes nodes."

floating_ips=$(openstack floating ip list -f value -c "Floating IP Address" )
floating_ip_bastion=$(echo "$floating_ips" | awk 'NR==1')

while true; do
    echo "restart"
    available_nodes=()
    unreachable_nodes=()

    # ping hosts
    for ((i = 1; i <= num_nodes; i++)); do
        node_name="${tag}_Node$i"
        node_ip=$(openstack server show -f value -c addresses "${node_name}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
            pingResult=$(ssh -i id_rsa.pub ubuntu@$floating_ip_bastion "ping -q -c 1 $node_ip" ) 
            if (-n $pingResult ) ; then
                available_nodes+=("$node_name")
            else
                unreachable_nodes+=("$node_name")
            fi
    done

    echo "Servers with ping:"
    for server in "${available_nodes[@]}"; do
        echo "  $server"
    done

    echo "Servers without ping:"
    for server in "${unreachable_nodes[@]}"; do
        echo "  $server"
    done 

    num_available_nodes="${#available_nodes[@]}"
    num_unavailable_nodes="${#unreachable_nodes[@]}"

    if [ "$num_available_nodes" -eq "$num_nodes" ]; then
        echo "Checking solution, we have: $num_available_nodes nodes. Sleeping for 30 seconds.."
        sleep 30
        continue
    else
        echo "Number of available nodes is less than $num_nodes. Performing recovery actions.."
        for Server in "${unreachable_nodes[@]}"; do
            echo "  $Server"
            ServerUnreachableExists=$(openstack -q server show -f value -c name "$Server" 2>/dev/null)
            if [ -n "$ServerUnreachableExists" ]; then
                echo "$formatted_time The server with the tag '$tag' already exists but not available: $Server" so it will be delete
                    if openstack server delete "$Server"; then
                        echo "$formatted_time Releasing $Server"
                        createServer $Server 
                    else
                        echo "$formatted_time Failed to release $Server"
                    fi
            else
                echo "  $Server does not exist so it will be create"
                createServer $Server 
            fi
        done 
    fi
done


# Create the  server
createServer ( ) {
    local Server=$1
    openstack server create --flavor "$flavor" --image "$image_id" --network "$NetworkName" \
    --security-group "$SecurityGroup" --key-name "$KeyName" "$Server" >/dev/null 2>&1 
    server_exists1=$(openstack -q server show -f value -c name "$Server" 2>/dev/null)
    sleep 10
    if [ -n "$server_exists1" ]; then
        echo "$formatted_time Proxy server created with the name '$server_exists1'"
        new_ip=$(openstack server show -f value -c addresses $Server | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
        replace_node_ip_sshConfig $Server, $new_ip 
        sleep 2
        playbook
    fi       
}


# Function to replace IP address for a specific node
replace_node_ip_sshConfig() {
    # SSH into the bastion and read the content of ~/.ssh/config
    ssh_lines=$(ssh -i id_rsa.pub ubuntu@"$floating_ip_bastion" 'cat ~/.ssh/config')

    local node_name=$1
    local new_ip=$2
    # Use awk to find the line containing "HostName" for the specified node and replace the IP address
    ssh_lines=$(echo "$ssh_lines" | awk -v node="$node_name" -v ip="$new_ip" '
        /^Host / {
            host_entry = $2;
        }
        host_entry == node && $1 == "HostName" {
            $2 = ip;
        }
        { print }
    ')
    # Write the updated SSH config file
    printf "%s\n" "$ssh_lines" > "config"
    scp  -o BatchMode=yes config ubuntu@$floating_ip_bastion:~/.ssh
}

playbook(){
echo "$formatted_time Running playbook..."
# Run the Ansible playbook on the Bastion server
ssh -i id_rsa.pub ubuntu@$floating_ip_bastion "ansible-playbook -i ~/.ssh/hosts ~/.ssh/site.yaml "
}




