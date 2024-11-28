# Right, what's all this then?
This is a collection of scripts and automations that I use/am working on. I put them into a GIT repo so I could shuffle them around easier, however the repo is not autonomous. It expects a jump host/dev VM (though a lot of that setup has been automated too) with credentials to the machines it is to manage.

# Supporting files
Since these aren't standardized across the industry, here are mine:
```
$USER/
├─ .kube/
│  ├─ id_mgmt_ed25519
│  ├─ id_mgmt_ed25519.pub
│  ├─ kubeadm_join.txt
├─ common/
│  ├─ inventory.yaml
│  ├─ prox_auth.yaml
├─ .ssh/
│  ├─ id_ed25519
│  ├─ id_ed25519.pub
│  ├─ id_rsa
│  ├─ id_rsa.pub
│  ├─ known_hosts
```

Where,

`/.kube/id_*` are the SSH keys used to manage Kubernetes worker nodes *as root*.

`/.common/inventory.yaml` has your ansible inventory

`/.ssh/` has *your* SSH keys, for example, to push to GitHub.

`common` is provided as a template for copy-paste convenience.

# Folders
This changes from time to time; I'll try to keep it updated. Ideally, this toolset is meant to be run from the root folder, this avoids relying too heavily on `../` but it's not possible to implement that all the time.

## ansible
A collection of useful stuff for Ansible, incleading a readme with common ansible commands and an inventory of my machines/IPs. Perfect for publishing on the internet...

### playbooks
Ansible playbooks for common administration tasks.

### kubernetes
Can provision an Ubuntu 22.04 Server > ready-to-join Kubernetes node. This is a *tool*; additional documentation is in the folder.

## bash
These range from a collection of commands looped into a `.sh`, to actual scripts that I plan on writing. They help with annoying tasks that I do often. These aren't great, because my bash is pretty bad (I get paid to write PowerShell, and in comparison BASH is a hard sell), but they're better than nothing.

## norun-scripts
Absolutely do not run, use them as workbooks. They're mostly made of garbage, they don't run but the commands are annoying to find on the internet and here they're in one place.

## var-scripts
These have variables that need to be edited, that I was too lazy to parameterize as prompts. Open, configure, run.

## scripts
These will probably work fine, or have some basic error handling to keep them from breaking everything.

# vyos
This one's pretty cool.

For reasons likely related to monies, getting a stable VyOS build is hard. So, they make you [build it yourself](https://docs.vyos.io/en/latest/contributing/build-vyos.html), which is also hard. This script will do that leg work for you, expects Docker and not much else. I gave it its own folder, and did some hax to the `.gitignore`, so the script would be the only thing caught by version control.
```
. vyos/build-vyos.sh
```