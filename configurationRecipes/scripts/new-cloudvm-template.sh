# Creates a new Ubuntu (jammy) template VM in Proxmox
# Benjamin Rohner
# 2024-05-11

# Setup folder
cd ~/
mkdir downloads
cd downloads

# Grab ISO
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Create VM
qm create 9000 --name "bm1-2204jammy-cloudinit-template" --bios ovmf -efidisk0 local-lvm:1,format=raw,efitype=4m,pre-enrolled-keys=1 --ostype l26 --memory 4096 --balloon 2048 --cpu x86-64-v2-AES --cores 4 --net0 virtio,bridge=bprd0008 --agent 1
# Add imported disk to VM
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0,size=32G
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --serial0 socket --vga serial0


# Convert to template
qm template 9000