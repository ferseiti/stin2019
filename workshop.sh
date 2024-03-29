#!/bin/bash
set -e

function usage()
{
    printf "\nScript that creates a virtual cluster made of lxd containers."
    printf "\n"
    echo "Usage: ./"`basename "$0"` '--login <LOGIN_NAME> --node1 <NODE_1_NAME>'
    echo ""
    echo "Options:"
    echo "  -l, --login <LOGIN_NAME>               Name for the login node."
    echo "  --node1 <NODE_1_NAME>                  Name for the computing node 1."
    # echo "  --node2 <NODE_2_NAME>                Name for the computing node 2."
    echo "  -h, --help                             Print this help message."
    echo ""
    exit 1
}

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -l|--login)
    STIN_LOGIN="$2"
    shift # past argument
    shift # past value
    ;;
    --node1)
    STIN_NODE_1="$2"
    shift # past argument
    shift # past value
    ;;
    # --node2)
    # STIN_NODE_2="$2"
    # shift # past argument
    # shift # past value
    # ;;
    -h|--help|*)    # print usage
    HELP=1
    usage
    shift # past argument
    ;;
esac
done

export STIN_LOGIN
export STIN_NODE_1
# export STIN_NODE_2
export re='^[0-9]+$'

if ( [ -z $STIN_LOGIN ] || [ -z $STIN_NODE_1 ] ) && [ -z $HELP ]; then
    echo "Error: all arguments are mandatory."
    usage
    exit 1
fi

NODES_NAME="$STIN_NODE_1"


sudo apt install -y lxd
cat <<EOF | sudo lxd init --preseed
config: {}
networks:
- config:
    ipv4.address: auto
    ipv6.address: none
  description: ""
  managed: false
  name: lxdbr0
  type: ""
storage_pools:
- config: {}
  description: ""
  name: default
  driver: dir
profiles:
- config: {}
  description: ""
  devices:
    eth0:
      name: eth0
      nictype: bridged
      parent: lxdbr0
      type: nic
    root:
      path: /
      pool: default
      type: disk
  name: default
cluster: null
EOF



# cp slurm-original.conf slurm.conf
sudo rm -f munge.key
# install containers

# sudo apt install -y lxd
# sudo lxd init

# Would you like to use LXD clustering? (yes/no) [default=no]: 
# Do you want to configure a new storage pool? (yes/no) [default=yes]: 
# Name of the new storage pool [default=default]: 
# Name of the storage backend to use (dir, lvm) [default=dir]: 
# Would you like to connect to a MAAS server? (yes/no) [default=no]: 
# Would you like to create a new local network bridge? (yes/no) [default=yes]: 
# What should the new bridge be called? [default=lxdbr0]: 
# What IPv4 address should be used? (CIDR subnet notation, “auto” or “none”) [default=auto]: 
# What IPv6 address should be used? (CIDR subnet notation, “auto” or “none”) [default=auto]: none
# Would you like LXD to be available over the network? (yes/no) [default=no]: 
# Would you like stale cached images to be updated automatically? (yes/no) [default=yes] 
# Would you like a YAML "lxd init" preseed to be printed? (yes/no) [default=no]: 

# get cpu information
# lscpu

# CPUS=`ncpu`

CPUS=2
ALL_CPUS=`lscpu | grep '^CPU(s):' | cut -f2 -d':' | sed 's; ;;g'`
# init containers
sudo lxc init ubuntu: $STIN_LOGIN -c "security.privileged"=true -c "user.user_data"="apt_preserve_sources_list: true"
sudo lxc init ubuntu: $STIN_NODE_1 -c "security.privileged"=true -c "limits.cpu"=$CPUS  -c "user.user_data"="apt_preserve_sources_list: true"
sudo lxc list
# start containers
sudo lxc start $STIN_LOGIN
sudo lxc start $STIN_NODE_1
sleep 30
# sudo lxc exec $STIN_NODE_1 bash
# update
sudo lxc file push sources.list $STIN_NODE_1/etc/apt/
sudo lxc file push sources.list $STIN_LOGIN/etc/apt/
sudo lxc exec $STIN_LOGIN -- apt update
sudo lxc exec $STIN_LOGIN -- apt upgrade -y
sudo lxc exec $STIN_NODE_1 -- apt update
sudo lxc exec $STIN_NODE_1 -- apt upgrade -y

# o arquivo não permanece
sudo lxc file push sources.list $STIN_NODE_1/etc/apt/
sudo lxc exec $STIN_NODE_1 -- apt update
# install
sudo lxc exec $STIN_NODE_1 -- apt install -y openmpi-bin libopenmpi-dev python3-pip
sudo lxc exec $STIN_NODE_1 -- pip3 install numpy matplotlib mpi4py

# For the students to perform:

# lxc exec $STIN_NODE_1 -- apt install -y slurmd munge
# lxc exec $STIN_LOGIN -- apt install -y slurmctld munge
# copy from one node to another
#    lxc copy $STIN_NODE_1 $STIN_NODE_2
# lxc file pull $STIN_LOGIN/etc/munge/munge.key munge.key
# lxc file push munge.key $STIN_NODE_1/etc/munge/munge.key
# lxc file push munge.key $STIN_NODE_2/etc/munge/munge.key
# lxc exec <all_nodes> -- chown munge:munge /etc/munge/munge.key

# lxc exec $STIN_LOGIN -- mkdir /var/spool/slurmctld
# lxc exec $STIN_LOGIN -- chown slurm:slurm /var/spool/slurmctld
#  configure slurm.conf
# lxc file push slurm.conf <TODOS_OS_CONTAINERS>
#  restart todos os containers
