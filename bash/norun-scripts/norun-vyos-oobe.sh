# Benjamin Rohner
# 2024-03-31
# Initial configuration of a VyOS install, to get it ready for ansible management. Run on VyOS.

configure

# List interfaces on thy system
show interfaces

# Basic LAN/WAN configuration
set interfaces ethernet eth0 address dhcp
set interfaces ethernet eth0 description 'OUTSIDE'
set interfaces ethernet eth1 address '192.168.0.1/24'
set interfaces ethernet eth1 description 'INSIDE'

# Make it managable
set service ssh port '22'

# Allow management from WAN

# Set the state
commit

# Save the config
save