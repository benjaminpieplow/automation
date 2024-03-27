# Right, what's all this then?
This is a collection of ansible playbooks that help build and maintain a Kubernetes cluster. Make sure to read each step before running the code!

## Prerequisites
If not done already, create an SSH key for use in the cluster. This is expected as `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_ansible`, and must be updated in `add-ssh-key.yaml` and `inventory.yaml` if you are BYOK.

# New node
This had to be done with two playbooks and a command to avoid annoying prompts/errors.

## Node Prep

**SWAP** is a royal bastard. I haven't found a good way to automate its removal, and it doesn't consistently get created so, if you're unsure, be safe. SSH into the node, `sudo -i`, run `swapon -s`; if you get a Filename back, `nano /etc/fstab` and comment out the "swap" line, then bounce the node. I'll automate this when it becomes a sizeable pain in the rear.

1. Add the key to the new machine (note, change the IP, *leave the trailing comma*):

`ansible-playbook -i 10.0.0.1, ./ansible/playbooks/add-ssh-key.yaml`

2. Add the node to `./ansible/inventory.yaml`, ideally creating a new group. You should be able to figure that out yourself.

3. Run the main book. This takes a *hot* minute.

`ansible-playbook -i ./ansible/inventory.yaml ./kubernetes/provision_k8s_node.yaml`

You can restrict the script to only OOBE your node with,

`ansible-playbook -i ./ansible/inventory.yaml --limit NODE_GROUP_NAME ./kubernetes/provision_k8s_node.yaml`

At this point, you will

1. have nothing set up
    * Build management machine
    * New Cluster
    * Join nodes to cluster
2. have a management machine but no cluster
    * New Cluster
    * Join nodes to cluster
3. have a cluster
    * Join nodes to cluster

## Join node to cluster
You can paste the `kubeadm join ...` command the master node gave you directly into a newly provisioned worker node; it will join the cluster and automations will continue configuring it.

If you're like me, you lost the original token it gave you. Run this on a machine authorized to control the cluster (master or management machine)

`kubeadm token create --print-join-command`

The output of this command can pasted directly into a node, once it's finished the init playbook. Adding `sudo` in front will increase the odds of it working.

### Node maintenance
If the cluster is misbehaving, you can bounce it with,

Everything: `ansible-playbook -i ./ansible/inventory.yaml ./ansible/playbooks/k8s_nodes bounce.yaml`

Nodes: `ansible-playbook -i ./ansible/inventory.yaml --limit k8s_nodes bounce.yaml`

Node: `ansible-playbook -i inventory.yaml --limit $BAD_NODE bounce.yaml`


You can use this command to blindly update the nodes to the latest software. Kubernetes *strongly* discourages this (instead encouraging stateful package versioning), but I don't see their Ansible playbook in your terminal, so...

`ansible-playbook -i inventory.yaml --tags "update" provision_k8s_node.yaml`

If the cluster is misbehaving, you can bounce it with,

`ansible-playbook -i inventory.yaml --limit k8s_nodes bounce.yaml`

# New Cluster
Not part of the playbook, since Ansible doesn't have a Kubernetes module, but odds are if you're here, this is the next step.

```
# SSH to the node you want as master
#TODO: Test if this works with DNS (#TODO, fix DNS...)
ssh -i ~/.ssh/id_ed25519_ansible root@$MASTER_NODE_IP

# Create the cluster (WARNING: This command outputs a `kubeadm join ...` command. **SAVE THAT**)
kubeadm init --apiserver-advertise-address=$MASTER_NODE_IP --pod-network-cidr=192.168.0.0/16

```

## Grab the cluster's administration/connection info
Note: copy this into whatever host you use to administer the cluster. Run this from your management machine

```
mkdir -p $HOME/.kube
scp -i ~/.ssh/id_ed25519_ansible root@$MASTER_NODE_IP:/etc/kubernetes/admin.conf ~/.kube/config
#sudo chown $(id -u):$(id -g) $HOME/.kube/config
```


`kubectl` will now connect to the newly created cluster, you can test it with `kubectl get nodes` To install kubectl, see below.

## Configure cluster networking

After doing this a few times, I think the best option is to just use canal:
```
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/canal.yaml
```



# Management Machine
This is a machine used to administer the Kubernetes cluster; it's not required, nor bound to a single cluster.

1. Download

`curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"`

2. Validate (can probably skip this step)

`curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"`

Then,

`echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check`

3. Install

`sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl`


## Install the kubectl-calico plugin on your management machine
Grab the binary:

`curl -L https://github.com/projectcalico/calico/releases/latest/download/calicoctl-linux-amd64 -o kubectl-calico`

Promote it:

`chmod +x kubectl-calico`

Install it:

`sudo cp kubectl-calico /usr/local/bin`

Test it (expected output: "kubectl-calico [options] <command> [<args>...]"):

`kubectl calico -h`

# Garbage/Archive
Stuff I *think* I don't need anymore but am too afraid to delete.




## Configure Network Manager

Note: The documentation for this got shredded in the import, this must be redone.

**NETWORK MANAGER** I haven't gotten around to automating this either.

```
mkdir /etc/NetworkManager/conf.d/
nano /etc/NetworkManager/conf.d/calico.conf

```

Add the following

```
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:tunl*;interface-name:vxlan.calico;interface-name:vxlan-v6.calico;interface-name:wireguard.cali;interface-name:wg-v6.cali
```

## Configure Netowrking
If that doesn't work, you'll probably have to nuke the cluster and try these steps. *Please* update the documentation, skip the above line, and pick up from here.

Part of the install script is to set up a CNI *interface* on each node, but IPAM and other garbage must still be done by hand. A *plugin* (Calico) handles this for us.

```
# Ensure cluster is running and kubectl can communicate with it
kubectl get nodes
# control-plane node should be NotReady

# Install Networking (do this once)
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/tigera-operator.yaml
```

### Let Kubernetes handle networking
If you're going to let Kubernetes handle networking (**STRONGLY** encouraged) you can feed the deployment directly into kubectl:

`kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/custom-resources.yaml`

### Manually configure Kubernetes networking
If you're still yearning for that learning, download it to customize the manifest. These steps don't work, obviously I gave up halfway through.

```
# Download a "manifest", this must be customized.
mkdir networking
cd network
curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/custom-resources.yaml -O
```

Modify the manifest to suit your network. I'm not going to pretend to know how this works, [docs](https://docs.tigera.io/calico/latest/networking/ipam/change-block-size#about-ip-pools). Change "cidr" to at minimum a /26 network that Kubernetes can consume (will only be used by pod-pod communication). Next, configure Calico:

`kubectl create -f custom-resources.yaml`



