# Interesting links and web resources

## To read/ Info

https://medium.com/@jain.sm/flannel-vs-calico-a-battle-of-l2-vs-l3-based-networking-5a30cd0a3ebd

Flannel/ Calico / Canal: https://www.youtube.com/watch?v=3eAVHt3lyuM

## Debugging/ troubleshooting

https://ystatit.medium.com/how-to-change-kubernetes-kube-apiserver-ip-address-402d6ddb8aa2
```bash
# Stop Services
systemctl stop kubelet docker

# Backup Kubernetes and kubelet
mv -f /etc/kubernetes /etc/kubernetes-backup
mv -f /var/lib/kubelet /var/lib/kubelet-backup

# Keep the certs we need
mkdir -p /etc/kubernetes
cp -r /etc/kubernetes-backup/pki /etc/kubernetes
rm -rf /etc/kubernetes/pki/{apiserver.*,etcd/peer.*}

# Start docker
systemctl start docker

# Get current public ip address
IP=$(curl -s ifconfig.me)

# Init cluster with new ip address
kubeadm init --control-plane-endpoint $IP \
--ignore-preflight-errors=DirAvailable--var-lib-etcd

# Verify resutl
# kubectl cluster-info
```



https://kubernetes.io/docs/tasks/debug-application-cluster/_print/

https://docs.openshift.com/enterprise/3.1/admin_guide/sdn_troubleshooting.html

# Commands

- Add an IP address to an interface

  ```bash
  ip addr add 191.168.99.102/24 dev eth0
  ```

- ```bash
  kubectl cluster-info dump | grep -m 1 service-cluster-ip-range
  kubectl cluster-info dump | grep -m 1 cluster-cidr
  kubeadm config print init-defaults | grep Subnet
  kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}'
  ```


- ```bash
  kubectl get nodes
  kubectl describe node rpi4a
  kubectl get node rpi4a -o yaml
  
  kubectl get pods --all-namespaces
  
  watch kubectl get pods -n calico-system
  watch kubectl get pods --all-namespaces
  
  kubectl delete pod <PODNAME> --grace-period=0 --force --namespace <NAMESPACE>
  ```
  
  

In case you face any issue in kubernetes, first step is to check if kubernetes self applications are running fine or not.

Command to check:- `kubectl get pods -n kube-system`

If you see any pod is crashing, check it's logs

if getting `NotReady` state error, verify network pod logs.

if not able to resolve with above, follow below steps:-

1. `kubectl get nodes` # Check which node is not in ready state
2. `kubectl describe node nodename` #nodename which is not in readystate
3. ssh to that node
4. execute `systemctl status kubelet` # Make sure kubelet is running
5. `systemctl status docker` # Make sure docker service is running
6. `journalctl -u kubelet` # To Check logs in depth

Most probably you will get to know about error here, After fixing it reset kubelet with below commands:-

1. `systemctl daemon-reload`
2. `systemctl restart kubelet`

In case you still didn't get the root cause, check below things:-

1. Make sure your node has enough space and memory. Check for `/var` directory space especially. command to check: `-df` `-kh`, `free -m`
2. Verify cpu utilization with top command. and make sure any process is not taking an unexpected memory.

## Remove a node

```yaml
kubectl drain <node name> --delete-local-data --force --ignore-daemonsets
kubectl delete node <node name>
```

## Uninstall K8S

First remove the nodes....



```yaml
sudo kubeadm reset -f

echo y | sudo apt-get purge kubectl kubeadm kubelet kubernetes-cni kube*
# sudo apt-get autoremove -y
sudo rm -fr /etc/kubernetes /var/run/kubernetes /etc/cni /opt/cni /var/lib/cni /var/lib/etcd ~/.kube

sudo iptables -F && sudo iptables -X
sudo iptables -t nat -F && sudo iptables -t nat -X
sudo iptables -t raw -F && sudo iptables -t raw -X
sudo iptables -t mangle -F && sudo iptables -t mangle -X

# remove all running docker containers
# sudo -E crictl rm -f `crictl ps -a | grep "k8s_" | awk '{print $1}'`
# sudo -E docker rm -f `docker ps -a | grep "k8s_" | awk '{print $1}'`

sudo shutdown -r now

```
