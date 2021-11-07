# Bare setup of K8S
Install basic components into the kubernetes cluster
## Network driver
Need to check the differences/ how it exactly works. And it router can replace flannel (or not)

**Flannel**
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
\-or\-
**Router**
kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml



## Install kubernetes dashboards with RBAC

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.4.0/aio/deploy/recommended.yaml


cat <<EOF | kubectl create -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
EOF

cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
EOF

### command to get token ###
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
```

### Access dashboard

On the machine having dashboard installed: kubectl proxy&

On the machine you want to view the dashboard: ssh -L 

## Setup heapster

We are installing heapster to get metrics on kubernetes dashboard.

```
git clone https://github.com/kubernetes/heapster.git
kubectl apply -f heapster/deploy/kube-config/rbac/heapster-rbac.yaml
kubectl apply -f heapster/deploy/kube-config/standalone/heapster-controller.yaml
```

## Setup helm

Helm is a tool for managing Kubernetes charts. Charts are packages of pre-configured Kubernetes resources.

```
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash

helm init

### create service account for helm ###
kubectl create serviceaccount --namespace kube-system tiller

### create cluster rolebinding for helm ###
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

### create patch for tiller ###
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

helm init --service-account tiller --upgrade
```

## Handy commands

Check what services are running

```bash
kubectl get deploy,svc -n kube-system
```
```bash
kubectl get services --all-namespaces
```
