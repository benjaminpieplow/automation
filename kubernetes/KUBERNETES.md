# Right, what's all this then?
This is an enormous toolkit I built to help me build and maintain Kubernetes clusters. Make sure to read each step before running the code!

# Overview
This kit has 3 main functions:
* Build underlying infrastructure for running K8s (management, VMs, network)
* Structure tools you will _likely_ need, and put them in a common location to get ahead of sprawl
* Build a Kubernetes cluster

## Folder Structure
### `./archive`
Old snippets that are referenced from time-to-time, but not actively maintained/do nothing.

### `./oobe`
These are Ansible playbooks to either build or update a kubernetes cluster. They are run from the management machine against the worker nodes. All commands in this document expected to be run from the `/automation/kubernetes/` folder, and find these files in `/automation/kubernetes/oobe`.

`provision_k8s_node-containerd.yaml` for "docker" runtime

`provision_k8s_node-cri-o.yaml` for "podman" runtime

#### `./oobe/templates`
These are config files the Ansible playbooks need to reference/provision during their work. They generally don't need touching.

`calico.conf` configures host networking to ignore calico-managed NICs

`containered_config_default.conf` when Docker installs containered, it changes some settings to optimize containerd for Docker. Put it back.

`module_kubernetes.conf` loads the kubernetes networking requirements at system boot (`br_netfilter` into `modules-load.d`)

`sysctl.conf` enables `net.ipv4.ip_forward=1` by replacing `/etc/sysctl.conf`. This *really* expects a freshly provisioned VM.


## Steps Overview
This guide picks up after [configuring your management machine](#management-machine)

1. [Provision VMs in Proxmox](https://github.com/benjaminpieplow/automation/wiki/New-K8s-Node-Cluster#provision-vms-in-proxmox)
2. [Configure VMs for Kubernetes](https://github.com/benjaminpieplow/automation/wiki/New-K8s-Node-Cluster#configure-vms-for-kubernetes)
3. [Create a cluster](https://github.com/benjaminpieplow/automation/wiki/New-K8s-Node-Cluster#create-a-cluster)
4. [Try again](https://github.com/benjaminpieplow/automation/wiki/New-K8s-Node-Cluster#screwed-up)

## Quality of Life fixes
These are things you should build into your workflow, either using your `.bashrc`, aliases, or memorization.

**Save your inventory in a variable** to avoid having to type the full path into each `ansible` command.
```
inventoryDir="~/common/inventory.yaml"
```

**Set the location of your current kubernetes config file** to avoid having to specify it in every `kubectl` command. Where `CLUSTERNAME` is something that uniquely identifies your cluster.
```
export KUBECONFIG=$HOME/.kube/config-CLUSTERNAME
```

Hint: `kubectl` looks for `$HOME/.kube/config`, if it does not find this, it tries the localhost. If you have a dedicated management machine (not running a cluster), and don't create a `.kube/config`, you can effectively add a check to make sure you're running in the right cluster by hard-coding your dev cluster into your `.bashrc`, reducing the risk of accidentally blasting something into production, taking down the entire client app and leading to an awkward call between them, your boss, and his boss.

**Create a folder for your Git repos** so as to keep non-git code separate from version-controlled code. I have this repo in `~/source/automation`; I *strongly* suggest keeping your code structured this way. If you have a different folder for your git codes, you will need to update it yourself, AFAIK this is not hard-coded in any scripts, but all commands (in this document) are written to expect it.
```
mkdir ~/source
cd ~/source
git clone ...
```

# Provision VMs in Proxmox
This is where the real meat-and-potatoes begins; this is the first step required for every K8s cluster you build. This will create VMs in Proxmox, ready to be remotely administered using a pre-specified key. The playbook reboots the VM, so if your router (say OPNsense) is configured to register DHCP hostnames in DNS, you can fire this, get a coffee, and SSH into the machine.

Ultimately, all this does is create an Ubuntu Server VM and install a root SSH key; you can do the same "your way", just make sure you can run the test at the end, and you account for configuration drift.

## Prerequisites
On your management machine, you will need,

* [Ansible installed](https://github.com/benjaminpieplow/automation/blob/main/bash/scripts/ansible_install.sh)
* `~/common/auth/proxmox` has valid [proxmox.yaml](https://github.com/benjaminpieplow/automation/blob/main/common/auth/proxmox.yaml)
* `~/common/inventory.yaml` has valid [inventory.yaml](https://github.com/benjaminpieplow/automation/blob/main/common/inventory.yaml) (hint: replace proxbar)


You can test this with,

```
ansible-playbook -vvvv --inventory $inventoryDir ~/source/automation/ansible/playbooks/proxmox/test_proxmox.yaml -e "proxmox_node_name=cluster_foo"
```

Where `cluster_foo` is the name of your Proxmox node in `~/common/auth/proxmox.yaml`. The output will include some JSON containing,
```
ok: [localhost] => {
    "changed": false,
    "invocation": {
        "module_args": {
            "api_host": "proxbar.bar.com",
            <other stuff>
        }
    },
    "proxmox_nodes": [
        {
            "status": "online",
            "type": "node",
            <other stuff>
        }
    ]
}
```

## Steps
### Create a template
Script: **Line by line** run [jammy-template-9000.sh](https://github.com/benjaminpieplow/automation/blob/main/bash/scripts/jammy-template-9000.sh) on a proxmox node. I will automate this *eventually*.

### Create a VM
Run the following ansible-playbook. Notes,

* You will be prompted for required info
* It takes 5+ minutes, as Ansible pushes through some restarts
* These can be run in parallel (use screen or multiple SSH windows) up to the capacity of your hypervisor. If you do too many at once, the reboot times out and you will have a bad day (nuke the VM and try again).

```
ansible-playbook -vvvv --inventory $inventoryDir ~/source/automation/ansible/playbooks/proxmox/new-US-2204-k8s.yaml
```

-- OR -- with all variables,

```
inventoryDir="~/common/inventory.yaml"
ansible-playbook --inventory $inventoryDir ~/source/automation/ansible/playbooks/proxmox/new-US-2204-k8s.yaml \
-e "vm_ram_max=8192 vm_ram_startup=2048 proxmox_node_name=node-foo vm_nic0_vlan=1 vm_name=vm-bar vm_id=123"
```

Where,

* `vm_ram_max` is max ballooning RAM
* `vm_ram_startup` is RAM at startup
* `vm_name` is hostname of the VM (also used in Proxmox)
* `vm_id` is the ID the VM will get in Proxmox
* `proxmox_node_name` is the name of your Proxmox node in `~/common/auth/proxmox.yaml`
* `vm_nic0_vlan` is the ID of the VLAN the VM's primary NIC will be tagged with (currently broken; uses VLAN ID from template)

### Test connection to the VM
To skip mucking around with passwords, I don't set one, which means Ubuntu won't let you log into the machine. To get around this, check DHCP for IPs and SSH in using,
```
ssh root@10.0.0.1 -i ~/.kube/id_mgmt_ed25519
```


# Configure VMs for Kubernetes
This uses a Playbook to bring VMs into a ready-to-join state. It expects the VM was built on the Ubuntu Jammy templates created above.

## Prerequisites
This assumes you are working from a management machine that is *not* going to be part of the cluster. It requires,

* [Ansible installed](https://github.com/benjaminpieplow/automation/blob/main/bash/scripts/ansible_install.sh)
* `~/common/inventory.yaml` has valid [inventory.yaml](https://github.com/benjaminpieplow/automation/blob/main/common/inventory.yaml) (hint: fill in k8s)
* nodes reachable via SSH

You can test this with,

```
ansible-playbook -vvvv --inventory $inventoryDir --limit k8s ~/source/automation/ansible/playbooks/test_host.yaml
```

The output will include some JSON containing,
```
PLAY RECAP **********
<host1>        : ok=2
<host2>        : ok=2
<host3>        : ok=2
```

## Steps
This has been consolidated into a single playbook. Either this works, or your day gets long.

`cri-o` "Podman" runtime:
```
ansible-playbook --inventory $inventoryDir --limit k8s --tags "oobe" ~/source/automation/kubernetes/oobe/provision_k8s_node-cri-o.yaml
```

`containerd` "Docker" runtime:
```
ansible-playbook --inventory $inventoryDir --limit k8s --tags "oobe" ~/source/automation/kubernetes/oobe/provision_k8s_node-containerd.yaml
```

# Create a Cluster
A Kubernetes cluster is administered from a cluster member often called a Master Node. This step configures this node, it therefore must be done before joining nodes to the cluster. Do this if building a new cluster.

## Prerequisites
This assumes you are working from a management machine that is *not* going to be part of the cluster. It requires,
* [kubectl installed](#prepare-the-management-machine)
* node configured using `provision_k8s_node-CCC.yaml`

This also assumes a good deal of "you know what you are doing". Generic, I know; here are some lessons I learned the hard way.

* DNS can be used to address nodes in *most* scenarios; for cluster administration, making that IP static can save you a respectable amount of ouch.
* You need to know how [cluster networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/) works, why you need Calico *and* NGINX, and why you will never (want to) reach the `--pod-network-cidr` range from your routed network. You will need this range defined; If using a SARCASM-compliant network plan, 192.168.0.0/16 can be used for this purpose.

## Steps

1. SSH to the node you want as master
```
ssh -i ~/.kube/id_mgmt_ed25519 root@$MASTER_NODE
```

2. Create the cluster
```
kubeadm init --apiserver-advertise-address=$MASTER_NODE_IP --pod-network-cidr=192.168.0.0/16
```

This command outputs a very handy `kubectl join` command, which I suggest saving in your `~/.kube` folder. Forgot to save it? Get a fresh join command with

```
kubeadm token create --print-join-command
```

## Grab the cluster's administration/connection info
Note: copy this into whatever host you use to administer the cluster. Run this from your management machine, changing the `-CLUSTER` to a name uniquely identifying the cluster or removing it entirely.

```
mkdir -p $HOME/.kube
scp -i ~/.kube/id_mgmt_ed25519 root@$MASTER_NODE_IP:/etc/kubernetes/admin.conf ~/.kube/config
#sudo chown $(id -u):$(id -g) $HOME/.kube/config-CLUSTER
```


`kubectl` will now connect to the newly created cluster (optionally, with `--kubeconfig ~/.kube/config-CLUSTER`), you can test it with `kubectl get nodes` To install kubectl, see below.

## Join worker nodes to cluster
Run the `kubeadm join` command on each worker node.

## Configure cluster networking
Straight from [Install Calico](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises#install-calico).

On your management machine, run

```
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
```

Next, download a file you _think_ you will customize, until you realize it is way above your paygrade and fire the stock config at your cluster.
```
mkdir ~/k8s-admin
cd ~/k8s-admin
curl https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml -O
# nano custom-resources.yaml
kubectl create -f custom-resources.yaml
```

Before moving on to the next step, a prayer or drink is _strongly_ suggested.

```
watch kubectl get pods -n calico-system
```

You should see a result similar to the below.
```
NAMESPACE     NAME                READY   STATUS                  RESTARTS         AGE
kube-system   calico-node-txngh   1/1     Running                   0              54s
```

## Configure ingress (NGINX)

### Aside: Why _two_ NGINXs?
So... I wanted this to be a technical guide, not a theory/course, but given how long it took me to figure it out, I'm including it here. Skip the Aside for the steps to deploy.

As far as I can tell, [via](https://bentoluiz.dev/self-hosting/linux/ubuntu/kubernetes/2023/06/22/selfhosting-5-loadbalancer/), there are two deployments of NGINX that make this setup highly available.

- Entrypoint/Edge _load balancer_
- Cluster _ingress controller_

The problem this has to solve is, when you (from the outside) ask for `https://example.com/foo`, your client has no idea what pod will resolve this request, it simply does an `nslookup` for `example.com` and chucks the request at the IP address returned by DNS. To solve that problem, a system must be aware of which pod(s) are currently available to give you `/foo`, so you don't get the pod running `/bar`. This is done by the _ingress controller_, it routes traffic delivered to the cluster around, to the pod that's currently in the mood to talk to you. The second problem you have is, how do you find that ingress service? Via DNS, duh, but even if you have your cluster nodes exposed to the internet (don't), how do you make sure you give the client an IP of a node that currently exists/functions? Hope? No, that problem is solved by a _load balancer_ which can be deployed to be highly available and serve multiple clusters/services, for example, using a dedicated hardware-accelerated F5 load balancer, or the NGINX service built into your router (because you're too poor to even get a _quote_ for an F5 BIG-IP). The _load balancer_ abstracts requests from the _node_ answering their query, and the _ingress controller_ abstracts requests from the _pod_ answering their query.

To make this work, the NGINX _ingress controller_ runs an instance (a pod) on each node, exposing itself on the node's IP using a "node port", a not-443 port (eg. 30535). This listens for HTTP requests destined for the cluster. The "upstream" NGINX _load balancer_ instance (F5/router) is aware of the nodes and continuously monitors their availability.

For an example, assume a 3-node cluster. Only Node3 can be reached by the load balancer, only Node2 has an App pod, and only Node1 has a functional ingress controller. Will the admin be fired? When a request comes in, it takes the following path:

![Request diagram](/kubernetes/archive/ingress.drawio.svg)

- (Green) Client -> Load Balancer:443
  - Load balancer unwraps TLS
  - Load balancer determines only Node3's HTTP service is available
  - Load balancer forwards request to Node3:30535
- (Orange) Load Balancer -> Node3
  - Node3's NodePort service determines the request must go to NGINX Ingress Controller
  - (Yellow) Node3 forwards the request to Node1's NGINX
- (Red) Node1/Ingress Controller -> APP:8443
  - Ingress controller determines request must go to App
  - Ingress controller knows only Node2 has an available App instance
  - Ingress Controller forwards request to Node2
- App processes the request, and it flows "back" to the client. The admin keeps their job.

This second communication happens over the "cluster network", that's what we need Calico for. This guide has you deploy IP-in-IP (default), but you can wrap this with encryption if moving over insecure networks, negating the need to give each App a certificate. Effectively, this networking plugin ensures that as long as a node is healthy, pods are given IP addresses reachable by the ingress controller, regardless of which node(s) either is running on. The [official documentation](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/#over-a-nodeport-service) suggests using MetalLB, but also says it's in Beta, and I don't know MetalLB so... Here we are.

You can read about other NGINX solutions [here](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/).

## Deploy NGINX Ingress Controller
By default, the helm chart install NGINX in a mode where it randomly selects a nodeport from a range (30000 - 32767). This does not help us, because our upstream load balancer/proxy will not run `kubectl -n ingress-nginx get svc` to figure out where it can find the service. Instead, we have to bind NGINX to a specific nodeport. To do this, we'll edit the helm chart for the baremetal deployment.

Download the raw configuration.
```
mkdir nginx
cd nginx
helm show values ingress-nginx --repo https://kubernetes.github.io/ingress-nginx >> nginx_config.yaml
```

Edit the `controller: service: nodePorts:` section with your choice of ports (I am using 31080 and 31443 to avoid collisions). See example `nginx_config.yaml`, or:
```
    nodePorts:
      # -- Node port allocated for the external HTTP listener. If left empty, the service controller allocates one from the configured node port range.
      http: 31080
      # -- Node port allocated for the external HTTPS listener. If left empty, the service controller allocates one from the configured node port range.
      https: 31443
```

You can test your configuration with:
```
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  -f ./nginx_config.yaml \
  --namespace ingress-nginx --create-namespace \
  --dry-run >> plan.yaml
```

Once that looks good, cross your fingers and _fire_.
```
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  -f ./nginx_config.yaml \
  --namespace ingress-nginx --create-namespace
```

Check your deployment with,
```
$ helm list -A
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
ingress-nginx   ingress-nginx   3               2024-12-10 20:07:22.509610325 +0000 UTC deployed        ingress-nginx-4.11.3    1.11.3     

$ kubectl get pods -n ingress-nginx
NAME                                       READY   STATUS    RESTARTS       AGE
ingress-nginx-controller-cbcf8bf58-s9klv   1/1     Running   6 (5m7s ago)   8m15s
```

### Configure downstream load balancer (NGINX on OPNsense)
This section is very specific to my homelab, but chances are the steps will be the same if you use your own upstream, so it might help.

For each worker node,

- Create an Upstream Server
  - Description: Something useful
  - Server: FQDN of the node (IP should work, haven't tested it though)
  - Port: Port set above (`31443` recommended)

When creating upstream servers:

- If using port `31443`, make sure to either uncheck "TLS: Verify Certificate", or ensure NGINX trusts the server certificates

## Add cluster storage
Recommended reading: [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes) and [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes). Through some dark magic, NFS seems to punch in the same weight-class as AzureFile and CephFS, so I will use that. We will create a storage class which applications can use to create Persistent Volumes (PVs) based on Persistent Volume Claims (PVCs); this will abstract storage management "for the most part". As Kubernetes [does not maintain](https://kubernetes.io/docs/concepts/storage/storage-classes/#provisioner) an NFS "Internal Provisioner", an external one must be used and according to [stackoverflow](https://stackoverflow.com/questions/43295344/kubernetes-dynamic-persistent-volume-provisioning-using-nfs), [subdir](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) seems to be the way to go. 

This guide expects that you have an NFS share already, which,

- can be accessed from all of your nodes
- the cluster has read-write permissions to
- `nfs-utils` installed on nodes (done if using the node prep playbook)
- (_strongly_ recommend) configuring IP range restrictions on the NFS share, as NFS uses client-side verification

For permissions, I have had the most luck with creating a service user on the NAS (eg. `nfsdataowner`), assigning user `chown nfsdataowner:nfsdataowner`, `chmod 770` permissions to the share (dataset), then setting Mapall User to `nfsdataowner`.

You can test/troubleblast your configuration by running `watch showmount -e FILE_SERVER` from a node. Expected output (note this does not test permissions):
```
Export list for FILE_SERVER:
/mnt/tank/dataset/share k8s01,k8s02,k8s03
```

Once that share is available, we can configure the Provisioner. This will be done via the [NFS Subdirectory External Provisioner Helm Chart](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner). On the management machine, run:
```
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=x.x.x.x \
    --set nfs.path=/exported/path \
    --set storageClass.defaultClass=true
```
Where, [values](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/blob/master/charts/nfs-subdir-external-provisioner/README.md):
- `nfs.server=x.x.x.x` is the IP or FQDN of your NFS server
- `nfs.path=/exported/path` is the path of the NFS share (seen in `showmount`)
- `storageClass.defaultClass=true` sets as the default storage class, so it is used by those pesky charts that don't expose storage class
- `storageClass.name=nfs-client` sets the name of the class (if creating multiple storage tiers)

Your pods will now be able to provision Persistent Volumes by creating a Persistent Volume Claim; the provisioner will negotiate with the NAS to create the files on the server. Alternatively, if you have multiple storage tiers, you can specify the class in your PVC (probably, I haven't tested this):

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 5Gi
```

# Screwed up?
🤣 troubleshooting? You fool! You are going to ☢️ the thing and start over.

Quickly get rid of a cluster by running this a few times,
```
ansible-playbook --inventory $inventoryDir ~/source/automation/ansible/playbooks/proxmox/destroy-vm.yaml \
-e "proxmox_node_name=cluster_foo vmid=000"
```

Where,

* `proxmox_node_name` is the name of your Proxmox node in `~/common/auth/proxmox.yaml`
* `vmid` is the ID of the VM to nonexist

You may also need to delete the old node's SSH keys,

```
ssh-keygen -f "~/.ssh/known_hosts" -R "10.0.0.101"
```

# Prepare the Management Machine
This is a machine used to administer the Kubernetes clusters; you don't need _this_ one, but you will have a hard time without one. This section builds a machine not bound to a single cluster, with some quality-of-life fixes..

1. **Generate SSH keys**

If not done already, create an SSH key for use in the cluster. I use `ssh-keygen -t ed25519 -f ~/.kube/id_mgmt_ed25519` to create a single key used across all clusters, optionally append the cluster name to make the key unique. Either way, the keys must be updated in `add-ssh-key.yaml` and `inventory.yaml`.

2. **Download `kubectl`**

`curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"`

3. **Validate `kubectl`** (can probably skip this step)

`curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"`

Then,

`echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check`

4. **Install `kubectl`**

`sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl`


## Install the kubectl-calico plugin on your management machine
Optional; required to administer calico networks. 

Grab the binary:

`curl -L https://github.com/projectcalico/calico/releases/latest/download/calicoctl-linux-amd64 -o kubectl-calico`

Promote it:

`chmod +x kubectl-calico`

Install it:

`sudo cp kubectl-calico /usr/local/bin`

Test it (expected output: "kubectl-calico [options] <command> [<args>...]"):

`kubectl calico -h`

## Install helm
Optional; required to install helm charts.

```
cd ~/downloads
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

---

# OLD WIKI: LEGACY DOCUMENTATION
This section was written over time, then split into the "wiki" and maintained there. That turned out to be _garbage_, so I migrated it back here. Now, I have to merge them; everything below this line is legacy or not yet integrated.



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


