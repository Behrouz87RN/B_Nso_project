# NSO_project

NSO project aims to automate the deployment and configuration of a network infrastructure using OpenStack and Ansible. It provides a set of programs and scripts to streamline the setup process.

*install
The INSTALL script is responsible for automating the deployment process. It performs the following tasks:
Loads environment variables from the OpenRC file for authentication.
Creates the required network infrastructure in OpenStack if it doesn't exist.
Creates a key pair for SSH access if it doesn't exist.
Creates a security group and adds the necessary rules for network access.
Creates and configures the servers using OpenStack APIs, including attaching floating IPs.
Generates an SSH config file and a hosts file for Ansible.
Executes an Ansible playbook for further configuration and provisioning of the network infrastructure.
playbook aims to automate the deployment and configuration of a Flask application on multiple nodes, configure HAproxy load balancer and monitoring, and set up monitoring tools such as Prometheus and Grafana on a Bastion host.
The Bashscript utilizes various OpenStack commands, Ansible playbook utilize for automation part and Telegraf and InfluxDB.
note: solution deploy ubuntu 22.04 Jammy Jellyfish x86_64 with image_name="19a8117d-39d6-40d2-bfbf-bc6d4d36adf8" and flavor "1C-2GB" flavor="b78dbffc-e512-4d87-a412-a971c6c5487d "   in sto2 region , if you want have other version of ubuntu please can image in  line 23 of install file and consider this image and flavor shave to existe in this region and also other versions of ubuntu may have problem with process of this project .
please follow this struct in command line :  install <openrc> <tag> <ssh_key>

*operate
Operate program  automates the deployment and management of a set of nodes in an OpenStack environment. It utilizes the OpenStack command-line tools and Ansible playbook for server creation, configuration, and deployment. The program reads a configuration file, server.conf, to determine the required number of nodes and checks the existing nodes in the environment with monitoring system ( Telegraf and InfluxDB). If the required number of nodes is not met, the program creates new nodes, fetches their IP addresses, and updates the hosts and SSH config files. It then runs an Ansible playbook to deploy the required services on the nodes. Finally, it validates the operation by accessing the nodes' IP addresses and prints the response content.
please follow this struct in command line :operate <openrc> <tag> <ssh_key>

*cleanup
Cleanup program cleans up resources created by the operate and install  programs in an OpenStack environment. It deletes the nodes, servers, subnets, networks, routers, key pairs, security groups, and volumes associated with the specified project. The program uses the OpenStack command-line tools to perform the cleanup tasks and prints the status of the remaining resources after the cleanup process is completed.
please follow this struct in command line :  cleanup <openrc> <tag> <ssh_key>


