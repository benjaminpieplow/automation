#!/bin/bash
# Author: Benjamin Rohner
# Date: 2024-10-13
# Desc: Creates a new Ubuntu Jammy template on a Proxmox host

read -p "Please enter the management ed-25519 public key (ssh-ed25519 AAAA....): " pubkey
read -p "Please enter the NIC VLAN tag: " vlantag

# get tools
apt install libguestfs-tools

# create the SSH key
# ssh-keygen...
echo pubkey > id_ed25519.pub

# get Ubuntu
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# customize the image using `virt-customize` provided by libguestfs-tools package.
virt-customize -a jammy-server-cloudimg-amd64.img --update
virt-customize -a jammy-server-cloudimg-amd64.img --install qemu-guest-agent
virt-customize -a jammy-server-cloudimg-amd64.img --ssh-inject root:file:id_ed25519.pub
# virt-customize -a jammy-server-cloudimg-amd64.img --run-command 'useradd --shell /bin/bash ansible'
# virt-customize -a jammy-server-cloudimg-amd64.img --run-command 'mkdir -p /home/ansible/.ssh'
# virt-customize -a jammy-server-cloudimg-amd64.img --ssh-inject ansible:file:/root/keys/id_mykeys.pub
# virt-customize -a jammy-server-cloudimg-amd64.img --run-command 'chown -R ansible:ansible /home/ansible'
# virt-customize -a jammy-server-cloudimg-amd64.img --upload /root/ansible:/etc/sudoers.d/ansible
# virt-customize -a jammy-server-cloudimg-amd64.img --run-command 'chmod 0440 /etc/sudoers.d/ansible'
# virt-customize -a jammy-server-cloudimg-amd64.img --run-command 'chown root:root /etc/sudoers.d/ansible'
virt-customize -a jammy-server-cloudimg-amd64.img --run-command '>/etc/machine-id' # important step so your clones get unique mac address / network details.

#create vm + customize
qm create 9000 --name "ubuntu-jammy-cloudinit-template" --memory 4096 --cores 4 --net0 virtio,bridge=vmbr0,tag=$vlantag
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm disk resize 9000 scsi0 64G
qm set 9000 --ipconfig0 ip=dhcp,ip6=dhcp
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1

# convert vm to template
qm template 9000
