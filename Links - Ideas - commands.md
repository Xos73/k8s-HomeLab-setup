# Interesting links and web resources
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

# Commands

- Add an IP address to an interface

  ```bash
  ip addr add 191.168.99.102/24 dev eth0
  ```






- ```bash
  kubectl get nodes
  kubectl describe node rpi4a
  kubectl get node rpi4a -o yaml
  
  kubectl get pods -n kube-system
  
  
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
