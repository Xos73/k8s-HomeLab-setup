#!/usr/bin/bash
#
KUBERNETES_VERSION=v1.30
PROJECT_PATH=stable:/v1.30

# Cleanup old keyring files
rm /etc/apt/keyrings/kubernetes-apt-keyring-*
rm /etc/apt/keyrings/cri-o-apt-keyring-*

# Add k8s apt source
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring-$KUBERNETES_VERSION.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring-$KUBERNETES_VERSION.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# Add cri-o apt source
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/$PROJECT_PATH/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring-$KUBERNETES_VERSION.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring-$KUBERNETES_VERSION.gpg] https://pkgs.k8s.io/addons:/cri-o:/$PROJECT_PATH/deb/ /" | tee /etc/apt/sources.list.d/cri-o.list

