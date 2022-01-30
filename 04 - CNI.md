# Install Networking stack

**Container networking** is the mechanism through which containers can optionally connect to other containers, the host, and outside networks like the internet. Container runtimes offer various networking modes, each of which results in a different experience. The idea behind the CNI (Container Network Interface) initiative is to create a framework for dynamically configuring the appropriate network configuration and resources when containers are provisioned or destroyed

Different options are possible as CNI  to use in Kubernetes.  You can find some insights at:

- [Comparing Kubernetes CNI Providers: Flannel, Calico, Canal, and Weave](https://www.suse.com/c/rancher_blog/comparing-kubernetes-cni-providers-flannel-calico-canal-and-weave/)
- [The Ultimate Guide To Using Calico, Flannel, Weave and Cilium](https://platform9.com/blog/the-ultimate-guide-to-using-calico-flannel-weave-and-cilium/)
- [Benchmark results for CNI plugins](https://itnext.io/benchmark-results-of-kubernetes-network-plugins-cni-over-10gbit-s-network-updated-august-2020-6e1b757b9e49)
- [CNI Benchmark: Understanding Cilium Network Performance](https://cilium.io/blog/2021/05/11/cni-benchmark)
- [Flannel vs Calico : A battle of L2 vs L3 based networking](https://medium.com/@jain.sm/flannel-vs-calico-a-battle-of-l2-vs-l3-based-networking-5a30cd0a3ebd)
- [MobiLab - Why we switched to Cilium](https://mobilabsolutions.com/2019/01/why-we-switched-to-cilium)
- [Youtube video on Flannel/ Calico / Canal](https://www.youtube.com/watch?v=3eAVHt3lyuM)

Flannel looks like the most straight forward solution. After some research (see above articles), I decide to setup Calico as CNI solution as it seems most fit to better understand the CNI setup.

Nevertheless, after reading the article about the impact of multiple iptables entries when publishing many services ([MobiLab - Why we switched to Cilium](https://mobilabsolutions.com/2019/01/why-we-switched-to-cilium)) and the fact AWS uses Cilium in their EKS, I decided to rebuild/ migrate from Calico to Cilium as CNI.

## Calico

### Install the control tool on arm64

In order to manage Calico APIs in the `projectcalico.org/v3` API group, you should use `calicoctl`. This is because `calicoctl` provides important validation and defaulting for these resources that is not available in `kubectl`. However, `kubectl` should still be used to manage other Kubernetes resources.

See https://docs.projectcalico.org/getting-started/clis/calicoctl/install

```bash
curl -o calicoctl -O -L  "https://github.com/projectcalico/calicoctl/releases/download/v3.21.0/calicoctl-linux-arm64" 
chmod +x calicoctl
sudo mv calicoctl /usr/local/bin/
```

### Install calico

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

### Change the MTU size with Calico

According to the Calico documentation ([Configure MTU to maximize network performance](https://docs.projectcalico.org/networking/mtu)), Calico CNI supports auto-detection and will auto-detect the correct MTU for your cluster based on node configuration and enabled networking modes. Nevertheless, at [Benchmark results for CNI plugins](https://itnext.io/benchmark-results-of-kubernetes-network-plugins-cni-over-10gbit-s-network-updated-august-2020-6e1b757b9e49), they state that this "auto-detect" mechanism is not working optimal and they advise to manually set the correct/ optimized MTU size to greatly improve the network performance.

Setting MTU to 9000 (jumbo frames) on a IP-in-IP configuration

```bash
kubectl patch configmap/calico-config -n kube-system --type merge -p '{"data":{"veth_mtu": "8980"}}'
kubectl rollout restart daemonset calico-node -n kube-system
```

### Testing the Calico network

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
ip route get [yourPhysicalGW] # That's the GW on your home network, not in the kubernetes cluster
```

> [yourPhysicalGW]  via 169.254.1.1 dev eth0  src 10.101.126.2

### Setup CNI RBAC

See https://docs.projectcalico.org/getting-started/kubernetes/hardway/end-user-rbac

### Monitoring and metering the Calico network with Graphana and Prometheus

Following the how-to at https://docs.projectcalico.org/maintenance/monitor/

#### Configure Calico to enable metrics reporting

Felix prometheus metrics are **disabled** by default. You have to manually change your Felix configuration (**prometheusMetricsEnabled**) via calicoctl in order to use this feature.

```bash
# Felix configuration
calicoctl patch felixConfiguration default  --patch '{"spec":{"prometheusMetricsEnabled": true}}'

# Create a service to expose Felix metrics
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: felix-metrics-svc
  namespace: kube-system
spec:
  selector:
    k8s-app: calico-node
  ports:
  - port: 9091
    targetPort: 9091
EOF

# kube controllers configuration are enabled by default

# Create a service to expose kube-controller metrics
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: kube-controllers-metrics-svc
  namespace: kube-system
spec:
  selector:
    k8s-app: calico-kube-controllers
  ports:
  - port: 9094
    targetPort: 9094
EOF

# Checking configuration
kubectl get services -A -o wide
```

#### Cluster preparation

```bash
# Namespace creation
kubectl apply -f -<<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: calico-monitoring
  labels:
    app:  ns-calico-monitoring
    role: monitoring
EOF

# Service account creation
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: calico-prometheus-user
rules:
- apiGroups: [""]
  resources:
  - endpoints
  - services
  - pods
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: calico-prometheus-user
  namespace: calico-monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: calico-prometheus-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: calico-prometheus-user
subjects:
- kind: ServiceAccount
  name: calico-prometheus-user
  namespace: calico-monitoring
EOF
```

#### Install prometheus

```bash
# Create promotheus config file
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: calico-monitoring
data:
  prometheus.yml: |-
    global:
      scrape_interval:   15s
      external_labels:
        monitor: 'tutorial-monitor'
    scrape_configs:
    - job_name: 'prometheus'
      scrape_interval: 5s
      static_configs:
      - targets: ['localhost:9090']
    - job_name: 'felix_metrics'
      scrape_interval: 5s
      scheme: http
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        regex: felix-metrics-svc
        replacement: $1
        action: keep
    - job_name: 'typha_metrics'
      scrape_interval: 5s
      scheme: http
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        regex: typha-metrics-svc
        replacement: $1
        action: keep
    - job_name: 'kube_controllers_metrics'
      scrape_interval: 5s
      scheme: http
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        regex: kube-controllers-metrics-svc
        replacement: $1
        action: keep
EOF

# Create promotheus pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: prometheus-pod
  namespace: calico-monitoring
  labels:
    app: prometheus-pod
    role: monitoring
spec:
  serviceAccountName: calico-prometheus-user
  containers:
  - name: prometheus-pod
    image: prom/prometheus
    resources:
      limits:
        memory: "128Mi"
        cpu: "500m"
    volumeMounts:
    - name: config-volume
      mountPath: /etc/prometheus/prometheus.yml
      subPath: prometheus.yml
    ports:
    - containerPort: 9090
  volumes:
  - name: config-volume
    configMap:
      name: prometheus-config
EOF

# Check pod is running
watch kubectl get pods -n calico-monitoring -o wide
```

#### Cleanup

By executing below commands, you will delete all the resource and services created by following this tutorial.

```bash
kubectl delete service felix-metrics-svc -n kube-system
kubectl delete service typha-metrics-svc -n kube-system
kubectl delete service kube-controllers-metrics-svc -n kube-system
kubectl delete namespace calico-monitoring
kubectl delete ClusterRole calico-prometheus-user
kubectl delete clusterrolebinding calico-prometheus-user
```

## Cilium

```
https://github.com/cilium/cilium-cli/releases/

curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-arm64.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-arm64.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-arm64.tar.gz /usr/local/bin
rm cilium-linux-arm64.tar.gz{,.sha256sum}
```

Install HELM

```bash
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

```bash
helm repo add cilium https://helm.cilium.io/
```

```
helm install cilium cilium/cilium --version 1.11.0 \
   --namespace kube-system \
   --set etcd.enabled=true \
   --set etcd.managed=true \
   --set etcd.k8sService=true
```

W1127 12:47:24.663070 3183469 warnings.go:70] spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[1].matchExpressions[0].key: beta.kubernetes.io/os is deprecated since v1.14; use "kubernetes.io/os" instead
W1127 12:47:24.663146 3183469 warnings.go:70] spec.template.metadata.annotations[scheduler.alpha.kubernetes.io/critical-pod]: non-functional in v1.16+; use the "priorityClassName" field instead
NAME: cilium
LAST DEPLOYED: Sat Nov 27 12:47:19 2021
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
You have successfully installed Cilium with Hubble.

Your release version is 1.10.5.