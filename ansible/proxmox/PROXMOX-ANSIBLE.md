# Right, what's all this then?
This page explains how to use the Ansible module for common Proxmox tasks. Find teh full documentation [here](https://docs.ansible.com/ansible/latest/collections/community/general/index.html)

# Create a VM
```
missing?
```

## Notes
```
update: true
```
Use this when updating any property. It will not allow you to create new VMs (kinda negating the point of ansible if you ask me but 😒 I guess I didn't pay for it)

---

```
ostype: l26
```
This sets the OS Type to Linux 6.x - 2.6 Kernel. Apparently it's the same as l24, I haven't found a difference yet.

---

```
memory: 4096
balloon: 2048
```
This is *super* counter-intuitive, `memory` sets the maximum memory, `balloon` sets the minimum memory.

---

```
cpu: x86-64-v2-AES
sockets: 1
cores: 4
vcpus: 2
```
Change `cpu` at your own risk.

`sockets` and `cores` multiply to give you the number of CPUs, but these can be limited with `vcpus`, "To start a VM with less than this total core count of CPUs, you may use the vpus setting, which denotes how many vCPUs should be plugged in at VM start." Bing says this can be changed on-the-fly, I'll believe it when I see it.

---





```
```
---