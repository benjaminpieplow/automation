# OLD WIKI: LEGACY DOCUMENTATION
This section was written over time, then split into the "wiki" and maintained there. That turned out to be _garbage_, so I migrated it back here. Now, I have to merge them; everything below this line is legacy or not yet integrated. Most of it can probably be deleted, but I'm afraid...


# New node
This had to be done with two playbooks and a command to avoid annoying prompts/errors. This guide assumes you have already provisioned the cluster nodes, and they are able to communicate with one another. See 

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

After doing this a few times, I think the best option is to just use canal.

Install the Tigera operator
```
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.1/manifests/tigera-operator.yaml
```

Install Calico: Download the custom resources yaml, update the IP to match the range provisioned in the cluster, then deploy it.
```
wget -4 https://raw.githubusercontent.com/projectcalico/calico/v3.28.1/manifests/custom-resources.yaml
nano custom-resources
kubectl create -f ./custom-resources.yaml
```

## Install Helm
I did not document this; IIRC this was fire-and-forget. Helm isn't *technically* needed, it's only useful if you want to use the cluster to run stuff.

## Install an ingress controller
The [quick start](https://kubernetes.github.io/ingress-nginx/deploy/) is right. Run this:
```
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

Test it:
```
$ kubectl get pods --namespace=ingress-nginx
NAME                                       READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-9756f5bd9-lkr5p   1/1     Running   0          9m28s
```

The Docu says "A few pods". One is a few... right?


