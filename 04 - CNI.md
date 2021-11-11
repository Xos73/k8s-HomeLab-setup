# Install Networking stack

**Container networking** is the mechanism through which containers can optionally connect to other containers, the host, and outside networks like the internet. Container runtimes offer various networking modes, each of which results in a different experience. The idea behind the CNI (Container Network Interface) initiative is to create a framework for dynamically configuring the appropriate network configuration and resources when containers are provisioned or destroyed

Different options are possible as CNI  to use in Kubernetes.  You can find some insights at:

- [Comparing Kubernetes CNI Providers: Flannel, Calico, Canal, and Weave](https://www.suse.com/c/rancher_blog/comparing-kubernetes-cni-providers-flannel-calico-canal-and-weave/)
- [The Ultimate Guide To Using Calico, Flannel, Weave and Cilium](https://platform9.com/blog/the-ultimate-guide-to-using-calico-flannel-weave-and-cilium/)
- [Benchmark results for CNI plugins](https://itnext.io/benchmark-results-of-kubernetes-network-plugins-cni-over-10gbit-s-network-updated-august-2020-6e1b757b9e49)
- [Flannel vs Calico : A battle of L2 vs L3 based networking](https://medium.com/@jain.sm/flannel-vs-calico-a-battle-of-l2-vs-l3-based-networking-5a30cd0a3ebd)
- Flannel/ Calico / Canal: https://www.youtube.com/watch?v=3eAVHt3lyuM

Flannel looks the most straight forward solution. I choose Calico as it seems most fit to better understand the CNI setup.

## Install the control tool on arm64

In order to manage Calico APIs in the `projectcalico.org/v3` API group, you should use `calicoctl`. This is because `calicoctl` provides important validation and defaulting for these resources that is not available in `kubectl`. However, `kubectl` should still be used to manage other Kubernetes resources.

See https://docs.projectcalico.org/getting-started/clis/calicoctl/install

```bash
curl -o calicoctl -O -L  "https://github.com/projectcalico/calicoctl/releases/download/v3.21.0/calicoctl-linux-arm64" 
chmod +x calicoctl
sudo mv calicoctl /usr/local/bin/
```

## Install calico

See https://docs.projectcalico.org/getting-started/kubernetes/self-managed-onprem/onpremises#install-calico-with-kubernetes-api-datastore-50-nodes-or-less

Below instructions will install the calico CNI into the kube-system namespace and create a contoller pod and a pod per node.

Side-effect: the core-dns pods will now be created and will go from status "ContainerCreating" to "Running" :-)

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
watch kubectl get pods -A -o wide

```

## Change the MTU size

According to the Calico documentation ([Configure MTU to maximize network performance](https://docs.projectcalico.org/networking/mtu)), Calico CNI supports auto-detection and will auto-detect the correct MTU for your cluster based on node configuration and enabled networking modes. Nevertheless, at [Benchmark results for CNI plugins](https://itnext.io/benchmark-results-of-kubernetes-network-plugins-cni-over-10gbit-s-network-updated-august-2020-6e1b757b9e49), they state that this "auto-detect" mechanism is not working optimal and they advise to manually set the correct/ optimized MTU size to greatly improve the network performance.

Setting MTU to 9000 (jumbo frames) on a IP-in-IP configuration

```bash
kubectl patch configmap/calico-config -n kube-system --type merge -p '{"data":{"veth_mtu": "8980"}}'
kubectl rollout restart daemonset calico-node -n kube-system
```

## Testing the network

Create three busybox instances

```bash
# Create three busybox instances
kubectl create deployment pingtest --image=busybox --replicas=3 -- sleep infinity

# Check their IP addresses
kubectl get pods -o wide --selector=app=pingtest

# Logon to one of the pods
TESTHOST=$(kubectl get pods -o wide --selector=app=pingtest --no-headers=true | head -n 1 | awk '{print $1}')
## Get console access to one of the hosts
kubectl exec -ti $TESTHOST -- sh
```

On the console in the created pod, you can execute some commands

```sh
ip addr sh # See that you have a /32 address --> That's how Calcio works
```

> 4: eth0@if11: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 8980 qdisc noqueue 
>     link/ether 1a:ea:07:0b:e1:44 brd ff:ff:ff:ff:ff:ff
>     inet 10.101.126.2/32 scope global eth0
>        valid_lft forever preferred_lft forever
>     inet6 fe80::18ea:7ff:fe0b:e144/64 scope link 
>        valid_lft forever preferred_lft forever

```sh
ip route get <yourPhysicalGW> # That's the GW on your home network, not in the kubernetes cluster
```
> <yourPhysicalGW>  via 169.254.1.1 dev eth0  src 10.101.126.2 

