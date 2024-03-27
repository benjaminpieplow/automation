# Ubuntu PXE Setup
# Benjamin Pieplow-Rohner
# 2021-11-04

ip="10.0.0.1" #IP of the SMB share containing SMB images

# Install required software
apt update && apt install -y dnsmasq tftpd-hpa pxelinux syslinux cifs-utils

# Mount folder containing PXE images
echo "//$ip/public/deployment/Shares/SC1-DeploymentShare/              /media/sc1-deploymentshare         cifs    username=instsa,password=c062ffce81be18b0d753d381ced5c9352c49ad500237ecb1a39b8729c81b35cc,uid=1000,gid=1000,iocharset=utf8,sec=ntlmv2,rw,vers=3       0       0" >> /etc/fstab
reboot


# Set up folder structure
mkdir /netboot/ && mkdir /netboot/tftp/ && mkdir /netboot/tftp/pxelinux && mkdir /netboot/tftp/pxelinux/pxelinux.cfg


# Fix eff'n Port 53 glitch
echo "dns=8.8.8.8" >> /etc/systemd/resolved.conf
echo "DNSStubListener=no" >> /etc/systemd/resolved.conf
reboot
# Verify with:
systemctl restart dnsmasq


# Configure dnsmasq
echo "enable-tftp" >> /etc/dnsmasq.conf
echo "tftp-root=/netboot/tftp" >> /etc/dnsmasq.conf


# Copy PXELinux into TFPT share
cp -r /usr/lib/syslinux/modules/ /netboot/tftp/pxelinux/
# Link MDT Share into TFTP share
ln -s /media/sc1-deploymentshare/ /netboot/tftp/sc1-deploymentshare

