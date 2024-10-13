# Ubuntu 20.04 New Server Setup
# Created for Ubuntu LXC Container as a Server

#### Interactive: Add new user ####
useradd $USER
# Fill out info
usermod -aG sudo $USER
su $USER
# Password
cd ~

# Enable remote access
sudo apt update
sudo apt install openssh-server ssh-import-id -y
sudo ufw allow ssh
ssh-import-id gh:$USER