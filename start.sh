#!/bin/sh

SOURCES_DIR=/src/ironic

function update_requirements {
    pip -c https://releases.openstack.org/constraints/upper/master \
    -r ${SOURCES_DIR}/requirements.txt \
    -r ${SOURCES_DIR}/test-requirements.txt
    pip install -U python-openstackclient
    pip install -U python-ironicclient
}

function update_ironic_source {
    git --git-dir=${SOURCES_DIR} pull origin master
}

function install_ironic_from_source {
    cd ${SOURCES_DIR}
    pip install .
}

while getopts 'hur' flag; do
    case "${flag}" in
        h)
        echo "options:"
        echo "-h    show brief help"
        echo "-u    Update all included requirements and pull the newest ironic source"
        echo "-r    Update all included requirements, don't touch the ironic sources"
        echo "-m    Use MySQL instead of default SQLite"
        exit 0
        ;;

        r)
        echo "Update all repos and requirements"
        update_requirements
            ;;

        u)
        echo "Update all repos and requirements"
        update_requirements
        echo "Pulling the newest ironic code"
        update_ironic_source
            ;;

        m)
        echo "Using MySQL database"
        MYSQL_USE=1
            ;;


      *)
            break
            ;;
    esac
  done

install_ironic_from_source

cd ${SOURCES_DIR}
# generate a sample config
oslo-config-generator --config-file=tools/config/ironic-config-generator.conf

# copy sample config and modify it as necessary
cp etc/ironic/ironic.conf.sample etc/ironic/ironic.conf.local

# disable auth since we are not running keystone here
sed -i "s/#auth_strategy = keystone/auth_strategy = noauth/" etc/ironic/ironic.conf.local

# use the 'fake-hardware' test hardware type
sed -i "s/#enabled_hardware_types = .*/enabled_hardware_types = fake-hardware/" etc/ironic/ironic.conf.local

# use the 'fake' deploy and boot interfaces
sed -i "s/#enabled_deploy_interfaces = .*/enabled_deploy_interfaces = fake/" etc/ironic/ironic.conf.local
sed -i "s/#enabled_boot_interfaces = .*/enabled_boot_interfaces = fake/" etc/ironic/ironic.conf.local

# enable both fake and ipmitool management and power interfaces
sed -i "s/#enabled_management_interfaces = .*/enabled_management_interfaces = fake,ipmitool/" etc/ironic/ironic.conf.local
sed -i "s/#enabled_power_interfaces = .*/enabled_power_interfaces = fake,ipmitool/" etc/ironic/ironic.conf.local

# set a fake host name [useful if you want to test multiple services on the same host]
sed -i "s/#host = .*/host = localhost/" etc/ironic/ironic.conf.local

# change the periodic sync_power_state_interval to a week, to avoid getting NodeLocked exceptions
sed -i "s/#sync_power_state_interval = 60/sync_power_state_interval = 604800/" etc/ironic/ironic.conf.local

# change RPC from default rabbitmq to JSON
sed -i "s/#rpc_transport =.*/rpc_transport = json-rpc/" etc/ironic/ironic.conf.local

# if you opted to install mysql-server, switch the DB connection from sqlite to mysql
if [[ "${MYSQL_USE:-0}" == 1 ]]; then
    sed -i "s/#connection = .*/connection = mysql\+pymysql:\/\/root:MYSQL_ROOT_PWD@localhost\/ironic/" etc/ironic/ironic.conf.local
fi

ironic-dbsync --config-file etc/ironic/ironic.conf.local create_schema

ironic-api -d --config-file etc/ironic/ironic.conf.local &> /var/log/ironic-api.log &
ironic-conductor -d --config-file etc/ironic/ironic.conf.local &> /var/log/ironic-conductor.log &
# let's give them time to start
while ! $(ls /var/log/ironic-api.log /var/log/ironic-conductor.log &>/dev/null); do sleep 1; done;
tail -f /var/log/ironic-*.log
