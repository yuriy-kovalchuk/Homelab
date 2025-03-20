echo "This script will run an Ansible playbook that will download a required cloud init base image in a proxmox server"

ansible-playbook -i ansible/playbook/inventory/hosts.ini ansible/playbook/download_base_image_playbook.yaml
