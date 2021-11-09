# Install cri-o and k8s

## Install needed packages
The Ubuntu standard versions can be used, but I prefer to download them directly from suse. It also ensures me that I have matching versions.

Perform the below steps on every single node participating in the cluster before joining them to the cluster

### Prepare package sources

```bash
# cri-o packages
export OS=xUbuntu_20.04
export VERSION=1.22

cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /
EOF

cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list
deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /
EOF

curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers.gpg add -

curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/Release.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers-cri-o.gpg add -

# k8s packages
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

```

### Install and configure thepackages

#### cri-o

- Install

  ```bash
  sudo apt-get update
  echo y | sudo apt-get install cri-o cri-o-runc
  
  ```

- Configure

  ```bash
  cat <<EOF | sudo tee /etc/crio/crio.conf
  conmon = "/usr/bin/conmon"
  EOF
  
  sudo systemctl enable crio.service
  sudo systemctl start crio.service
  
  ```

#### k8s
```bash
sudo apt-get update
echo y | sudo apt-get install kubeadm kubectl kubelet

sudo shutdown -r now

```

## Initialize k8s master

As I have a multihomed configuration, I want to only advertise my k8s environment on my Ethernet part of my cluster (not the WiFi part). I also specify my control plan in case I want to add multiple masters in the future.

```bash
sudo -E kubeadm init --apiserver-advertise-address=10.10.10.221 --control-plane-endpoint=10.10.10.221
```

***Note:** This will take some minutes and the output will provide you the necessary steps to continue setup.
Instructions below are copied from this output*

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Initialize additional control planes (optional)

Copy the used certificates to the other node(s) you want to configure as control planes

```bash
ssh rpi4b "mkdir -p /home/ubuntu/tmp/pki/etcd" && scp *.crt rpi4b:/home/ubuntu/tmp/pki/ && scp *.crt rpi4b:/home/ubuntu/tmp/pki/etcd/ && ssh rpi4b "sudo cp -bR /home/ubuntu/tmp/pki /etc/kubernetes/" && ssh rpi4b "sudo rm -rf /home/ubuntu/tmp"
```

Run following command on every to be control plane

```bash
kubeadm join 10.10.10.221:6443 --token <Your token> --discovery-token-ca-cert-hash sha256:ca2f.....3b1a --control-plane
```

## Initialize k8s worker node(s)

```bash
kubeadm join 10.10.10.221:6443 --token <Your token> --discovery-token-ca-cert-hash sha256:ca2f.....3b1a
```

