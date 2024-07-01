# HomeLab: Installing a K8S cluster on ProxMox
Goal is to get a hands-on experience lab to better know k8s, understand how security works in it and how to expose (securily) services running on a k8s cluster. (adding a touch of RBAC to the equation to spice things up)
Will be using an Ubuntu 24.04 LTS image to create my k8s clusters and I want them to be identical. So I will deploy them using a template in proxmox and configre them using ansible.
Proxmox is imho a nice hypervisor having just the right features to run multiple loads in a homelab (before spinning them in the cloud).

## Create Ubuntu template on ProxMox
I used the video on from "Learn Linux TV" as a guide to create my template
- https://www.youtube.com/watch?v=MJgIm03Jxdo&list=PLT98CRl2KxKHnlbYhtABg6cF50bYa8Ulo&index=20&t=1224s
- https://www.learnlinux.tv/proxmox-ve-how-to-build-an-ubuntu-22-04-template-updated-method/
1. Create a VM
   1. **General**: VM ID: <SomeNonConflicting_VM_ID>/ Name: <SomeMeaningfulName>
   2. **OS**: Do not use any media (will come back later on it)/ Linux 6.x - 2.6 kernel
   3. **System**: SCSI ctrl: VirtIO SCSI (not the single)/ Machine: I prefer i440fx (better perf as q35)/ Qemu Agent: Enabled/ BIOS: Default
   4. **Disks**: Remove the disks (will add a disk later)
   5. **CPU**: 1 socket/ 2 cores/ Type: host
       My proxmox clusters have all same/ very similar CPUs. CPU type setting is important when migrating VMs between different metal CPUs. Setting can affect performance.
       See https://www.techaddressed.com/tutorials/proxmox-improve-vm-cpu-perf/, https://pve.proxmox.com/wiki/Qemu/KVM_Virtual_Machines and https://www.yinfor.com/2023/06/how-i-choose-vm-cpu-type-in-proxmox-ve.html
   6. **Memory**: At least 2GB, prefereably 4GB for the workers
   7. **Network**: Bridge: <SelctYourBridge>/ Model: VirtIO / VLAN Tag: <FollowYourNetworkSetup>/ Firewall: disable
   8. Confirm
2. Download the linux image and configure seral port
    I am using the Ubuntu minimalistic cloud image to perform my installs, because i like to keep my footprint as light and small as possible.
    Download it from https://cloud-images.ubuntu.com/minimal/daily/noble/current/ -> noble-minimal-cloudimg-amd64.img (QCow2 disk image)
   1. Open the proxmox shell
   2. wget the file
   3. Rename the extension to .qcow2 (needed according to Learn Linux TV, did not test) > ubuntu-24.04-min.qcow2
   4. Resize the img file to the size of your HD (32G in my case) `qemu-img resize ubuntu-24.04-min.qcow2 32G`
   5. import the disk to the template VM : `qm importdisk <VM_ID> ubuntu-24.04-min.qcow2 local-lvm`
   6. `qm set <VM_ID> --serial0 socket --vga serial0` (allows you to see boot sequence mapping to screen)
3. Adapt the VM template settings
   1. Hardware
      1. Double click on the "Unused disk 0" (imported above). Add it with:
         1. Bus: SCSI:0
         2. If the metal disk in your ProxMox is an SSD:
            1. Discard: Enable
            2. (Advanced) SSD emulation: Enable
      2. Remove the CD drive
      3. Add the CD drive
         1. Bus: SCSI:6 (selecting SCSI allows hotswap...)
         2. Do not use media
      4. Add a CloudInit drive
         1. Bus: SCSI:7
         2. Storage: local-lvm (or something suiting your proxmox storage setup - I have no SAN or ZFS or ceph storage (yet))
      5. Check the serial port 0 is configured
   2. Cloud-Init settings
      1. Specify the default user (<Cloud_Init_User>) and his password
      2. If you do have a priv key you use to logon, this is the moment to add your public key counterpart
      3. IP config: leave in DHCP for now
      4. Regenerate Image
   3. Options
      1. Start at boot: yes
      2. Boot order: Enable scsi0 (and eventually re-order the list + disable the network card)
      3. Use tablet for pointer: Disable
4. Convert to template
5. Deploy a VM from the template. If needed adapt the IP address of the 

## Condition the machine using ansible
My preferred way to control my "ansible children" is by using certificates to authenticate the ansible controller user.
There are several options to join the freshly added machine to the ansible controller:
1. Logon to the ansible controler using the account you configured in the Cloud-Init setting
2. If you are using a specific ansible_user (configured in /etc/ansible/hosts) as I do, you can follow the below steps from the ansible controller:
   1. Edit /etc/ansible/hosts
      1. Add the new server(s) in the inventory
      2. Uncomment the ansible_user setting
   2. Manually ssh to the new server(s) using ssh <Cloud-Init_user>@new_server. Accept the certificate
   3. Run the script: `ansible-playbook -u <Cloud-Init_user> 1-ansibleUserCreation.yml`. (See https://docs.ansible.com/ansible/latest/collections/ansible/builtin/user_module.html for details)
   4. Run the script to copy the <ansible_user> pub key to the .ssh directory: `bash ./2-copy_ansible_user_pubkey.sh`
   5. Condition the sudo environment to allow the <ansible_user> to gain root privileges: `ansible-playbook -u <Cloud-Init_user> 3-sudoConfigure.yml`
   6. Edit /etc/ansible/hosts and undo uncommenting the ansible_user setting in the [all:vars] section
3. Baseline the machine to match your own baseline preferences (in my case: install vim and bash-completion)

## Prepare the Controller using ansible
Using ansible, you can easily condiftion the nodes to become k8s machines. apply the following ansible playbooks in order (look at the content for more info):
1. `ansible-playbook 4-k8s.yml`. This script configures and prepares the machines with:
   1. Disable swap
   2. Configure ip forwarding and allow bridged traffic to be inspected by iptables
   3. Load overlay and br_netfilter modules
   4. Download CRI-O as container component (calls an external script)
   5. Install CRI-O and k8s components
2. `ansible-playbook 5-reboot.yml`

## Create the k8s cluster
I called my controller "k8s-ctrl" and my worker nodes "k8s-node##".
To initialize the k8s cluster, login to the main controller
1. `ssh k8s-ctrl`
2. Initialize the k8s cluster. I used the IP address of my k8s-ctrl machine as both apiserver and control-plan endpoint.
   `sudo -E kubeadm init --apiserver-advertise-address=<controller_IP address> --control-plane-endpoint=<controller_IP address>`
   [!!] Write down the output of the initialisation command. It contains instructions on how-to join additional ctrl nodes and worker nodes [!!]
3. Join aditional control plane server:
   `ssh <k8s-ctrl2> "sudo kubeadm join <controller_IP address>:6443 --token <token_id> --discovery-token-ca-cert-hash <sha256:sha256_token> --control-plane"`
4. Join the k8s workers:
   `ssh <k8s-node##> "sudo kubeadm join <controller_IP address>:6443 --token <token_id> --discovery-token-ca-cert-hash <sha256:sha256_token>"`

## Install Cilium as CNI layer
- Run the ansible script `ansible-playbook 7-download-cilium-once_only.yml`
- Log on to the k8s-ctrl machine and install cilium using `cilium install --version 1.15.6`
- Wait and check installation on all nodes using `cilium status`
- Once cilium is installed and propagated on all nodes, also install hubble to get the needed observability `cilium hubble enable`
- Wait and check (again) installation on all nodes using `cilium status`
