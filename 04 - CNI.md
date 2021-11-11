# Install Networking stack

I'm using calico. 

In order to manage Calico APIs in the `projectcalico.org/v3` API group, you should use `calicoctl`. This is because `calicoctl` provides important validation and defaulting for these resources that is not available in `kubectl`. However, `kubectl` should still be used to manage other Kubernetes resources.

See https://docs.projectcalico.org/getting-started/clis/calicoctl/install

Install the control tool on arm64

```bash
curl -o calicoctl -O -L  "https://github.com/projectcalico/calicoctl/releases/download/v3.21.0/calicoctl-linux-arm64" 
chmod +x calicoctl
sudo mv calicoctl /usr/local/bin/
```

Install calico

See https://docs.projectcalico.org/getting-started/kubernetes/self-managed-onprem/onpremises#install-calico-with-kubernetes-api-datastore-50-nodes-or-less

```bash
curl -o calico-max50nodes.yaml -O -L https://docs.projectcalico.org/manifests/calico.yaml

# Edit file to align with your CIDR
## Find your CIDR
kubeadm config print init-defaults | grep Subnet
## Other way to find your CIDR
kubectl cluster-info dump | grep -m 1 service-cluster-ip-range
## Change the values
sed -i "s/# - name: CALICO_IPV4POOL_CIDR/- name: CALICO_IPV4POOL_CIDR/" calico-max50nodes.yaml
cidr=$(kubeadm config print init-defaults | grep Subnet | cut -d ":" -f2 | xargs)
sed -i "s|\#   value: \"192.168.0.0\/16\"|  value: \"$cidr\"|" calico-max50nodes.yaml

kubectl apply -f calico-max50nodes.yaml

# watch the deployment of the pods
watch kubectl get pods -A

```

