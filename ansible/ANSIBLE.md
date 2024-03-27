# Right, what's all this then?
I can't remember this garbage, so I'm writing it down as BASH history is, evidently, not enough.

# Common Commands
All commands assume you have set `inventoryDir="/path/to/inventory.yaml`

The command you're probably looking for is, `ansible-playbook --inventory $inventoryDir --limit $HOST $PLAYBOOK_YAML`

# Kubernetes
This gets its own folder, because it's more of an application toolkit; it does *a lot*. 

# Install Ansible
```
sudo apt install pipx -y
pipx install --include-deps ansible
```