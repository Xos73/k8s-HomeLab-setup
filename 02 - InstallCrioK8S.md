# Install cri-o and k8s

## Install needed packages
The Ubuntu standard versions can be used, but I prefer to download them directly from suse. It also ensures me that I have mathing versions

### cri-o

```bash
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

sudo apt-get install cri-o cri-o-runc -y


cat <<EOF | sudo tee /etc/crio/crio.conf
conmon = "/usr/bin/conmon"
EOF

sudo systemctl enable crio.service
sudo systemctl start crio.service
```

### k8s

```bash
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

sudo apt-get install kubeadm kubectl kubelet cri-o cri-o-runc cri-tools -y
```

## Initialize k8s master

As I have a multihomed configuration, I want to only advertise my k8s environment on my Ethernet part of my cluster (not the WiFi part). I also specify my control plan ein case I want to add multiple masters in the future.

```bash
kubeadm init --apiserver-advertise-address=192.168.99.10 --control-plane-endpoint=192.168.99.10
```

***Note:** This will take some minutes and the output will provide you the necessary steps to continue setup.
Instructions below are copied from this output*

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Initialize additional control planes (eventually)

Copy the used certificates to the other node(s) you want to configure as control planes

```bash
ssh rpi4b "mkdir -p /home/ubuntu/tmp/pki/etcd" && scp *.crt rpi4b:/home/ubuntu/tmp/pki/ && scp *.crt rpi4b:/home/ubuntu/tmp/pki/etcd/ && ssh rpi4b "sudo cp -bR /home/ubuntu/tmp/pki /etc/kubernetes/" && ssh rpi4b "sudo rm -rf /home/ubuntu/tmp"
```

Run following command on every to be control plane

```bash
kubeadm join 192.168.99.10:6443 --token <Your token> --discovery-token-ca-cert-hash sha256:ca2f.....3b1a --control-plane
```

## Initialize k8s worker node(s)

```bash
kubeadm join 192.168.99.10:6443 --token <Your token> --discovery-token-ca-cert-hash sha256:ca2f.....3b1a
```

