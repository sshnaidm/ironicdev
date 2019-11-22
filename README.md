Ironic Dev container
--------------------

Sometimes we need to develop Ironic on unprepared environment or need to show
something to newbies or even just run Ironic services to test things locally.
For that purpose there is a Ironic Dev container.
Based on [Developer Quick-Start](https://docs.openstack.org/ironic/latest/contributor/dev-quickstart.html#exercising-the-services-locally)
document I tried to make it as much user friendly as possible. All you need is
just a container tool. Everything that is mentioned with `podman` here can run
with `docker` in the same way with the same parameters.

For example we need to test some `openstack baremetal` commands and we need a
running Ironic services with fake nodes.
This is simple as is:

```bash
podman run -d --name test_ironic -d -p 6385:6385 sshnaidm/ironicdev
# or
docker run -d --name test_ironic -d -p 6385:6385 sshnaidm/ironicdev
```

Let's export authentication environment variables for running services:
```bash
export OS_AUTH_TYPE=token_endpoint
export OS_TOKEN=fake
export OS_ENDPOINT=http://127.0.0.1:6385
```
And now let's run a `openstack` commands:

```bash
openstack baremetal driver list
openstack baremetal node list
```
It works! Nothing is displayed because we don't have nodes yet.
Let's create them.
We can go simple way:
```bash
FAKE_NODE=$(openstack baremetal node create --driver fake-hardware --management-interface ipmitool --power-interface ipmitool -f value -c uuid)
openstack baremetal node show $FAKE_NODE
```

Or something more complicated:

```bash
MAC="aa:bb:cc:dd:ee:ff"   # replace with the MAC of a data port on your node
IPMI_ADDR="1.2.3.4"       # replace with a real IP of the node BMC
IPMI_USER="admin"         # replace with the BMC's user name
IPMI_PASS="pass"          # replace with the BMC's password

NODE=$(openstack baremetal node create \
       --driver fake-hardware \
       --management-interface ipmitool \
       --power-interface ipmitool \
       --driver-info ipmi_address=$IPMI_ADDR \
       --driver-info ipmi_username=$IPMI_USER \
       -f value -c uuid)
openstack baremetal node set $NODE --driver-info ipmi_password=$IPMI_PASS
openstack baremetal port create $MAC --node $NODE
openstack baremetal node show $NODE
openstack baremetal node validate $NODE
openstack baremetal node power on $NODE
```
and other commands that you can see in the [Developer Quick-Start](https://docs.openstack.org/ironic/latest/contributor/dev-quickstart.html#exercising-the-services-locally) document.

If you need to develop locally with prepared Ironic dev container with all services
running inside, you can mount your local sources to sources directory in the container:

```bash
podman run -d --name ironic -p 6385:6385 -v /path/to/sources/ironic:/src/ironic sshnaidm/ironicdev
# or
docker run -d --name ironic -p 6385:6385 -v /path/to/sources/ironic:/src/ironic sshnaidm/ironicdev
```
After you changed sources, all you need is just to restart the container to take effect:
```bash
podman restart ironic
# or
docker restart ironic
```

Let's try this. Clone sources to your local directory in ~/sources/ironic
```bash
git clone https://github.com/openstack/ironic ~/sources/ironic
podman run -d --name ironic -p 6385:6385 -v ~/sources/ironic:/src/ironic sshnaidm/ironicdev
# check that services are running
podman logs ironic
# Let's change log text for example
cd ironic
sed -i "s/RPC create_node called for node/Our new log: RPC create_node called for node/"  ironic/conductor/manager.py
# let's add a node
openstack baremetal node create --driver fake-hardware --management-interface ipmitool --power-interface ipmitool
podman logs -f | grep 'Our new log'
```
We see nothing because service still uses an old code.
Let's restart it:
```bash
podman restart ironic
# to check that service runs
podman logs
# if you see SQLAlchemy errors that's fine, schema is already in DB
# Let's create another node
openstack baremetal node create --driver fake-hardware --management-interface ipmitool --power-interface ipmitool
podman logs -f | grep 'Our new log'

2019-11-22 14:39:51.653 61 DEBUG ironic.conductor.manager [req-e2858b23-5e8a-44de-8f2d-58d92f67e6cf - - - - -] Our new log: RPC create_node called for node dce2237b-233f-40b7-bc93-70e7c368416f. create_node /usr/local/lib/python3.7/site-packages/ironic/conductor/manager.py:131
```
Voila! The service is using a new code.

Happy hacking!