# tinkerbell-vagrant

Setup Tinkerbell stack locally using Vagrant


## Steps

### Prerequisites

 - vagrant is installed, if not download from [here](https://www.vagrantup.com/downloads.html)
 - virtualization is enabled
    ```
      grep -o 'vmx\|svm' /proc/cpuinfo
    ```

### Install packages and dependencies 

```
sudo apt update && apt install qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils libguestfs-tools virt-manager
```

### Change provider to `libvirt`

```
export VAGRANT_DEFAULT_PROVIDER=libvirt
```


### Add user to libvirt group (probably not required)

```
sudo adduser $USER libvirt
sudo adduser $USER libvirt-qemu
```

### Start provisioner

```
vagrant up provisioner
```

### Start the workers

```
vagrant up bios_worker
vagrant up uefi_worker
```

### Monitor VMs with virt-manager

```
virt-manager
```

### Halt VMs

```
vagrant halt provisioner
vagrant halt bios_worker
vagrant halt uefi_worker
```

# Detroy VMs

```
vagrant destroy -f provisioner
vagrant destroy -f bios_worker
vagrant destroy -f uefi_worker
```
