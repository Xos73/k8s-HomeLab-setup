#!/usr/bin/bash
#
for RMT_NODE in k8s-ctrl k8s-node01 k8s-node02a k8s-node03

do
  ssh $RMT_NODE 'sudo mkdir /home/ansible/.ssh'
  scp -r /etc/ansible/keys/ansible.pem.pub $RMT_NODE:./authorized_keys
  ssh $RMT_NODE 'sudo mv ~/authorized_keys /home/ansible/.ssh/'
  ssh $RMT_NODE 'sudo chmod 700 /home/ansible/.ssh'
  ssh $RMT_NODE 'sudo chown -R ansible:admin /home/ansible/.ssh'
  ssh $RMT_NODE 'sudo chmod 600 /home/ansible/.ssh/authorized_keys'
done
