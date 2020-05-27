$provisioner_ip_address = '10.11.12.2'
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

Vagrant.configure('2') do |config|
  config.vm.box = 'generic/ubuntu1804'

  config.vm.provider :libvirt do |lv, config|
    lv.memory = 2*1024
    lv.cpus = 2
    lv.cpu_mode = 'host-passthrough'
    config.vm.synced_folder '.', '/vagrant', type: 'rsync'
  end

  config.vm.define :provisioner do |config|
    config.vm.hostname = 'provisioner'
    config.vm.network :private_network,
      ip: $provisioner_ip_address,
      libvirt__dhcp_enabled: false,
      libvirt__forward_mode: 'none'
    config.vm.provision :shell, path: 'provision-tinkerbell.sh', args: [$provisioner_ip_address]
  end

  ['bios', 'uefi'].each_with_index do |firmware, i|
    config.vm.define "#{firmware}_worker" do |config|
      config.vm.box = nil
      config.vm.network :private_network,
          ip: $provisioner_ip_address,
          mac: "08002700000#{i+1}",
          auto_config: false
      config.vm.provider :libvirt do |lv, config|
        lv.loader = '/usr/share/ovmf/OVMF.fd' if firmware == 'uefi'
        lv.memory = 2*1024
        lv.boot 'network'
        lv.mgmt_attach = false

        # optional BIOS settings
        # set some BIOS settings that will help us identify this particular machine.
        #
        #   QEMU                | Linux
        #   --------------------+----------------------------------------------
        #   type=1,manufacturer | /sys/devices/virtual/dmi/id/sys_vendor
        #   type=1,product      | /sys/devices/virtual/dmi/id/product_name
        #   type=1,version      | /sys/devices/virtual/dmi/id/product_version
        #   type=1,serial       | /sys/devices/virtual/dmi/id/product_serial
        #   type=1,sku          | dmidecode
        #   type=1,uuid         | /sys/devices/virtual/dmi/id/product_uuid
        #   type=3,manufacturer | /sys/devices/virtual/dmi/id/chassis_vendor
        #   type=3,version      | /sys/devices/virtual/dmi/id/chassis_version
        #   type=3,serial       | /sys/devices/virtual/dmi/id/chassis_serial
        #   type=3,asset        | /sys/devices/virtual/dmi/id/chassis_asset_tag
        [
          'type=1,manufacturer=your vendor name here',
          'type=1,product=your product name here',
          'type=1,version=your product version here',
          'type=1,serial=your product serial number here',
          'type=1,sku=your product SKU here',
          "type=1,uuid=00000000-0000-4000-8000-000000000000",
          'type=3,manufacturer=your chassis vendor name here',
          'type=3,version=your chassis version here',
          'type=3,serial=your chassis serial number here',
          'type=3,asset=your chassis asset tag here',
        ].each do |value|
          lv.qemuargs :value => '-smbios'
          lv.qemuargs :value => value
        end
        # end of optional BIOS settings

      end
    end
  end
end
