# Setup the OS
## Before first boot
### Format SD cards with the correct OS
I used the Raspberry Pi imager to download and transfer the required OS to the SD cards. You can find a copy of it at https://www.raspberrypi.com/news/raspberry-pi-imager-imaging-utility/.
Initially, I used raspbian OS 32bit, but because I wanted to go for a full k8s environment (and not k3s), I switched to the Ubuntu arm 64bit version

* Choose OS
* Other general purposes OS
* Ubuntu
* Ubuntu Server 20.04.3 LTS 64-bit

### Edit files on the SD card
To prevent from having to couple a screen to my RPI4 devices, I opted for the headless approach. Ubuntu is using cloud-init based configuration files. The cloud-init documentation has more details https://cloudinit.readthedocs.io/.

Below you'll find the changes I made on my SD cards:

> **Note:** If you want to do the same with Raspbian OS, you'll need to:
>
> * `touch ssh` A file names "ssh" should be present
> * add a `wpa_supplicant.conf` file in the root, containing your needed WiFi configuration


#### Configure IP address
On the Raspberry Pi 4, I have both an Ethernet connection and a WiFi connection. I've connected all Ethernet cards to a 5-port switch to have a network backbone for my cluster. My backbone has a 192.168.99.0/24 network. The WiFi connections are used as an "external" facing network.
***Note:** I had issues configuring the WiFi connection in headless mode. Had to fix it later after boot*

Edit the file `network-config`: (!) Please ensure the 2 space indents (!)

```yaml
version: 2
ethernets:
  eth0:
    addresses: [192.168.99.10/24]
wifis:
  wlan0:
    dhcp4: true
    optional: true
    access-points:
      "<wiFiNetworkName>":
        password: "<yourPassword>"

```
##### Some clarifications on the wifi section

- *dhcp4*: true ensures that your Raspberry Pi will ask your WiFi router for network settings, including DNS servers and an IP address. Likely, your router will assign another IP address in addition to the one you specified above. That is not a problem for now — it can be corrected later by configuring the router to assign a fixed IP address to your Raspberry Pi.
- Keep the *optional: true* setting. Since the <u>WiFi adapter will not be initialized on the first boot</u>, this setting will ensure that the boot process won't fail. We <u>will configure our Raspberry Pi for reboot just after the first boot</u>.
- In the *access-points* setting, enter your WiFi network name and password.
- Pay attention to *indents*! Each next inner level must have exactly 2 spaces (or a multiple of 2).

#### Edit the user-data file

##### Reboot to allow the wifi to become active

Edit the  `user-data` file, and append the following lines:

```yaml
...
runcmd:
- [ sed, -i, s/REGDOMAIN=/REGDOMAIN=BE/g, /etc/default/crda ]
- [ netplan, apply ]
# Reboot after cloud-init completes
power_state:
  mode: reboot
```

The *runcmd* part that invokes *sed* is essential if you wish to connect to the 5GHz WiFi network (Raspberry Pi 4 supports the *ac* standard). It adds the country code to the */etc/default/crda* file. The 5GHz standard has different restrictions depending on the country where it is used; thus, it won't work if the country is not specified. You can replace “BE” with your country code in the code snippet above.

The runcmd part that invokes *netplan apply* may be omitted on Ubuntu 20.04 but is required on newer Ubuntu versions.

The *power_state* part instructs our Raspberry Pi to reboot after the initialization. Thus, your WiFi network can be reached on the second boot.

##### Enable SSH server

When I wrote the Ubuntu image to my SD cards, the ssh server was already activated by default. Check below settings in the `user-data` file:

```
...
# Enable password authentication with the SSH daemon
ssh_pwauth: true
...
```

##### Other settings

This file `user-data`also contains other useful information and parametrisation:

1. Change password of "ubuntu" user at first login (default settings)

```yaml
...
# On first boot, set the (default) ubuntu user's password to "ubuntu" and
   # expire user passwords
   chpasswd:
     expire: true
     list:
     - ubuntu:ubuntu
...
```

2. Install additional packages on first boot (could be used to install std packages needed for setting up k8s)
3. Change keyboard layout (only needed when directly connecting to the rpi4, not through SSH)
### Web references
Guide was based upon https://roboticsbackend.com/install-ubuntu-on-raspberry-pi-without-monitor/
and https://sergejskozlovics.medium.com/how-to-set-up-a-wireless-ubuntu-server-on-raspberry-pi-89b84dca34d2 for the wifi setup at first boot

Headless setup with redirecting output to console https://limesdr.ru/en/2020/10/17/rpi4-headless-ubuntu/

Step-by-step at Ubuntu, but needing a monitor https://ubuntu.com/tutorials/how-to-install-ubuntu-core-on-raspberry-pi

## After reboot
### Switch Ethernet config from cloud-init to netplan

When booting from the SD card, cloud-init is used. Ubuntu can still use cloud-init, nevertheless they moved their config to netplan

#### If you followed the configuration steps above and wifi connects
```bash
sudo mv /etc/netplan/50-cloud-init.yaml /etc/netplan/00-installer-config.yaml
sudo sed -e '1,5d' < /etc/netplan/00-installer-config.yaml 

cat <<EOF | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
network: {config: disabled}
EOF

sudo netplan apply

ip address show

```

#### Or create/ edit manually the needed files
Create/ edit the following to `/etc/netplan/00-installer-config.yaml` file. Below example is using fixed IP for ethernet and dhcp for wifi

```yaml
network:
  version: 2
    ethernets:
    eth0:
      addresses: [192.168.99.10/24]
          nameservers:
              search: [yourdomain.local]
              addresses: [192.168.99.1]
          routes:
              - to: default
                via: 192.168.99.1
  wifis:
    wlan0:
      dhcp4: true
      access-points:
        "<wiFiNetworkName>":
          password: "<yourPassword>"

```
Both configs above and below are the working. Two different annotations are possible:

```yaml
network:
  version: 2
    ethernets:
    eth0:
      addresses:
          - 192.168.99.10/24
          nameservers:
              search:
                  - yourdomain.local
              addresses:
                  - 192.168.99.1
      routes:
          - to: default
            via: 192.168.99.1
  wifis:
    wlan0:
      dhcp4: true
      access-points:
        "<wiFiNetworkName>":
          password: "<yourPassword>"
```

Disable cloud-init

```bash
cat <<EOF | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
network: {config: disabled}
EOF

sudo rm -rf /etc/netplan/50-cloud-init.yaml
```
Apply the network changes

```bash
sudo netplan apply

ip address show
```

### Enable cgroup settings

```bash
sudo sed -i -e '$s/$/\ cgroup_enable=memory swapaccount=1 cgroup_memory=1 cgroup_enable=cpuset/' /boot/firmware/cmdline.txt
```

### Configure the needed kernel modules

```bash
modprobe overlay
modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system
sudo swapoff -a
```

### Personalisation
- Rename your server
  ```bash
  sudo hostnamectl set-hostname <newHostname>
  ```

- Change to vi as default editor
  ```bash
  sudo update-alternatives --set editor /usr/bin/vim.basic
  ```

- Add your own user to the system and create your ssh key
  ```bash
  sudo adduser <yourUser>
  sudo usermod -aG sudo <yourUser>
  ```

  Don't forget to adapt sudo rights and add the needed sudo entries
  ```bash
  sudo visudo
  ```
  \-or\-
  
  create a separate sudo file for all your device admins:
  
  ```bash
  sudo visudo -f /etc/sudoers.d/99-admins
  
  # User rules for admins
  <yourUser> ALL=(ALL) NOPASSWD:ALL
  
  ```

- Disable wifi and/or Bluetooth

  ```bash
  cat <<EOF | sudo tee -a /boot/firmware/usercfg.txt
  
  # Disabling wifi and Bluetooth
  dtoverlay=disable-wifi
  dtoverlay=disable-bt
  EOF
  
  ```



### Update the system and reboot the system

Could be that yu get the error message: `Could not get lock /var/lib/dpkg/lock-frontend`.
This is probaby because `/usr/bin/unattended-upgrade` is still running. Please wait it to finish (check with `ps -ef`)

```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y
sudo apt-get install apt-transport-https
sudo reboot
```

# Enable login through ssh keys

## From your normal workstation to the master node of the cluster

Use your preferred ssh key generator to create a key.

### Windows

On Windows, you can use the putty suite: `puTTYgen` --> use a RSA2 key with 4096 key length (2048 minimum)

Save both keys .ppk (private key) and .pub (public key)

Copy the public key to the home folder of the user you want to logon with to master node of the Raspberry Pi cluster

Move and rename the file

```bash
cat /home/ubuntu/user.pub >> /home/ubuntu/.ssh/authorized_keys
rm  /home/ubuntu/user.pub
```

### Linux

On Linux, use the command:

```bash
ssh-keygen -t rsa -b 4096 -C <your e-mail address>
```

Copy the public key to the home folder of the user you want to logon with to master node of the Raspberry Pi cluster

```bash
ssh-copy-id ubuntu@<masternode>
```

## From the master node to the other worker nodes

- If needed adapt the /etc/hosts file and add all the nodes with friendly names

  ```bash
  sudo vi /etc/hosts
  ```

- Generate a key pair on the master node

  ```bash
  ssh-keygen -t rsa -b 4096
  ```

- Install the public key on the other nodes

  ```bash
  ssh-copy-id ubuntu@rpi4b
  ```

  > ubuntu@rpi4a:~/.ssh$ ssh-copy-id ubuntu@rpi4b
  > /usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/home/xtophe/.ssh/id_rsa.pub"
  > The authenticity of host 'rpi4d (10.10.11.224)' can't be established.
  > ECDSA key fingerprint is SHA256:spE......Lyk.
  > Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
  > /usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
  > /usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
  > ubuntu@rpi4b's password:
  >
  > Number of key(s) added: 1
  >
  > Now try logging into the machine, with:   "ssh 'ubuntu@rpi4b'"
  > and check to make sure that only the key(s) you wanted were added.

