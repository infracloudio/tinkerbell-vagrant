## Issues

### error while running `vagrant up provisioner` command:

```
VirtualBox is complaining that the kernel module is not loaded. Please
run `VBoxManage --version` or open the VirtualBox GUI to see the error
message which should contain instructions on how to fix this error.
```

Solution: set the correct provider (libvirt/virtualbox) for vagrant by setting the environment variable as:
```
export VAGRANT_DEFAULT_PROVIDER=libvirt
```

