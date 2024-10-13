# ProxMox Out of Box setup
# Check for #! Configuration or ## Interactive
# This started as touchless, now it's interactive
# 2021-10-23

# Import SSH IDs from GitHub
apt-get update -y
apt-get install -y ssh-import-id
ssh-import-id gh:$USER



# Needed for containers to run the latest Linux distros(?)
pveam update
apt full-upgrade -y

# Disable Enterprise Update Channel (requires subscription)
sed -i '/^deb https:\/\/enterprise.proxmox.com\/debian\/pve bullseye pve-enterprise$/s/^/#/' /etc/apt/sources.list.d/pve-enterprise.list
# Disable "subscription" alert
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && systemctl restart pveproxy.service
# Enable seat-of-your-pants updates
echo "deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription" >> /etc/apt/sources.list

# End automated steps
exit




# Setup IPAM
apt update -y
apt install dnsmasq
# disable default instance
systemctl disable --now dnsmasq




# Clearing Disks
#! Repeat for every disk you want to use for vm storage, replacing sdX with device name
wipefs -a /dev/sdX

#! Alternate (interactive) to above, with fdisk
#fdisk /dev/sdX
#p
#d
#
# Repeat p -> d until no partitions left
#w

## Create ZFS Volume using WebUI
## Disks -> ZFS


# VLAN Awareness
## System -> Network -> iface -> CHeck "VLAN aware"
#! Restrict VLANs
nano /etc/network/interfaces
  #bridge-vids 1-4094


# Cluster/Ceph

# SMB Storage
# Datacenter > Storage > Add > SMB
# Add storage
