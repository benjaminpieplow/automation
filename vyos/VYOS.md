# Right, what's all this then?
This folder contains tools to prep and setup a VyOS instance.

# Building VyOS
Very simple,

```
#cd vyos
. build-vyos.sh
```

# Configure VyOS
This section assumes you have configured the infrastructure; the instance should have a NIC and you should have interactive console access.

## OOBE
Login: `vyos`/`vyos`

Quick Start: This gives you *enough* config to SSH in.
```
configure

# Get a list of interfaces, note the name of the interface you want LAN on
show interface

set interfaces ethernet eth1 address 192.168.0.1/24
set interfaces ethernet eth1 description 'LAN'

set service ssh port 22

commit
```
After this, use Ansible.