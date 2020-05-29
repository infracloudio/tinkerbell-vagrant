#!/bin/bash

# abort this script on errors.
set -euxo pipefail

provisioner_ip_address="${1:-10.10.10.2}"; shift || true


# prevent apt-get from opening stdin
# even with this, you'll still get some warnings that you can ignore:
#     dpkg-preconfigure: unable to re-open stdin: No such file or directory
export DEBIAN_FRONTEND=noninteractive

# install dependencies.
apt-get install -y curl jq

# remove the tput command because it breaks the vagrant execution.
apt-get remove --purge --allow-remove-essential -y ncurses-bin

# configure the network with netplan because
# ubuntu 18.04+ uses netplan instead.
# see https://github.com/tinkerbell/tink/issues/129
host_number="$(($(echo $provisioner_ip_address | cut -d "." -f 4 | xargs) + 1))"
nginx_ip_address="$(echo $provisioner_ip_address | cut -d "." -f 1).$(echo $provisioner_ip_address | cut -d "." -f 2).$(echo $provisioner_ip_address | cut -d "." -f 3).$host_number"
cat >/etc/netplan/60-eth1.yaml <<EOF
---
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
        - $provisioner_ip_address/24
        - $nginx_ip_address/24
EOF
netplan apply
# wait for the network configuration to be applied by systemd-networkd.
while [ -z "$(ip addr show eth1 | grep "$nginx_ip_address/24")" ]; do
  sleep 1
done

# install tinkerbell.
# see https://github.com/tinkerbell/tink/blob/master/docs/setup.md
export TB_INTERFACE='eth1'
export TB_NETWORK="$provisioner_ip_address/24"
export TB_IPADDR="$provisioner_ip_address"
export TB_REGUSER='tinkerbell'
cd ~

wget -qO- https://raw.githubusercontent.com/tinkerbell/tink/master/setup.sh | bash -x

# provision the example hello-world workflow action.
docker pull hello-world
docker tag hello-world $provisioner_ip_address/hello-world
docker push $provisioner_ip_address/hello-world

# provision the example hello-world workflow template.
# see https://tinkerbell.org/examples/hello-world/
docker exec -i deploy_tink-cli_1 sh -c 'cat >/tmp/hello-world-template.yml' <<EOF
version: '0.1'
global_timeout: 600
tasks:
  - name: hello-world
    worker: {{.device_1}}
    actions:
      - name: hello-world
        image: hello-world
        timeout: 60
EOF
template_output="$(docker exec -i deploy_tink-cli_1 tink template create --name hello-world --path /tmp/hello-world-template.yml)"
template_id="$(echo "$template_output" | perl -n -e '/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/ && print $1')"
docker exec -i deploy_tink-cli_1 tink template get "$template_id"

# provision the bios and uefi VM workers hardware and
# respective workflow.
# see https://tinkerbell.org/hardware-data/
for i in 1 2; do
  worker_host_number=$((10+$i))
  worker_ip_address="$(echo $provisioner_ip_address | cut -d "." -f 1).$(echo $provisioner_ip_address | cut -d "." -f 2).$(echo $provisioner_ip_address | cut -d "." -f 3).$worker_host_number"
  worker_mac_address="08:00:27:00:00:0$i"
  
  # create the hardware.
  docker exec -i deploy_tink-cli_1 tink hardware push <<EOF
{
  "id": "870fe43f-a58e-4f69-af39-0d612a6587c$i",
  "arch": "x86_64",
  "allow_pxe": true,
  "allow_workflow": true,
  "facility_code": "onprem",
  "ip_addresses": [
    {
      "enabled": true,
      "address_family": 4,
      "address": "$worker_ip_address",
      "netmask": "255.255.255.0",
      "gateway": "$provisioner_ip_address",
      "management": true,
      "public": false
    }
  ],
  "network_ports": [
    {
      "data": {
        "mac": "$worker_mac_address"
      },
      "name": "eth0",
      "type": "data"
    }
  ]
}
EOF
  docker exec -i deploy_tink-cli_1 tink hardware mac "$worker_mac_address" | jq .
  # create the workflow.
  workflow_output="$(docker exec -i deploy_tink-cli_1 tink workflow create -t "$template_id" -r "{\"device_1\": \"$worker_mac_address\"}")"
  workflow_id="$(echo "$workflow_output" | perl -n -e '/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/ && print $1')"
  docker exec -i deploy_tink-cli_1 tink workflow get "$workflow_id"
done

# show summary.
# e.g. inet 192.168.121.160/24 brd 192.168.121.255 scope global dynamic eth0
host_ip_address="$(ip addr show eth0 | perl -n -e'/ inet (\d+(\.\d+)+)/ && print $1')"
cat <<EOF

#################################################
#
# tink envrc
#

$(cat /root/tink/envrc)

#################################################
#
# addresses
#

kibana: http://$host_ip_address:5601

EOF
