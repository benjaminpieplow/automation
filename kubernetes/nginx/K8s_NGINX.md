# Right, what's all this then?
For nodes to move around the cluster, a service must route HTTP requests to a host capable of processing these requests; one that is running a pod of that service. An ingress controller supports this function, and I am using an [nginx in NodePort](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/#over-a-nodeport-service) deployment.

This requires all cluster prep steps to be completed, including Calico networking and helm.

# Install NGINX ingress controller
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
  -f ./nginx_overrides.yaml \
  --namespace ingress-nginx --create-namespace \
  --dry-run >> plan.yaml
```

Once that looks good, cross your fingers and _fire_.
```
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  -f ./nginx_overrides.yaml \
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