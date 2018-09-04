
# L2TP/tunneldigger broker-setup on Debian 9 "stretch"

* This documentation is not written for general use. It is more a personal manual about how I made the tunneldigger-broker work.
* For basic documentation check [Python-virtualenv](https://virtualenv.pypa.io/en/stable/) and [tunneldigger](https://tunneldigger.readthedocs.io/en/latest/server.html)
* Using modified hooks from [ff-Franken](https://github.com/rohammer/tunneldigger/tree/master/broker/scripts)

## Prerequisites
* 
* Added `l2tp_core l2tp_eth l2tp_netlink` to `/etc/modules` 
* Checked for modules: `find /lib/modules/$(uname -r) -type f -name \l2tp*.ko`
	/lib/modules/4.16.0-2-amd64/kernel/net/l2tp/l2tp_core.ko
	/lib/modules/4.16.0-2-amd64/kernel/net/l2tp/l2tp_netlink.ko
	/lib/modules/4.16.0-2-amd64/kernel/net/l2tp/l2tp_ppp.ko
	/lib/modules/4.16.0-2-amd64/kernel/net/l2tp/l2tp_ip.ko
	/lib/modules/4.16.0-2-amd64/kernel/net/l2tp/l2tp_eth.ko
	/lib/modules/4.16.0-2-amd64/kernel/net/l2tp/l2tp_debugfs.ko
	/lib/modules/4.16.0-2-amd64/kernel/net/l2tp/l2tp_ip6.ko
* Installed `iproute bridge-utils libnetfilter-conntrack-dev libnfnetlink-dev libffi-dev python-dev libevent-dev ebtables python-virtualenv`
* To repair defect linking installed `virtualenv` (sorry^^)
* Also installed `build-essential` to make the virtualenv build tunneldigger.

## Installation
```
cd /srv/tunneldigger
virtualenv env_tunneldigger
git clone https://github.com/wlanslovenija/tunneldigger.git
source env_tunneldigger/bin/activate
cd tunneldigger/broker
python setup.py install
```

## Configuration
Clone this repository into `/srv/tunneldigger/tunneldigger/broker/`, read `l2tp_broker.cfg` and
`cp /srv/tunneldigger/tunneldigger/broker/contrib-ffoh/tunneldigger.service /etc/systemd/system/tunneldigger.service` 
Or do it manualy:
```
cd /srv/tunneldigger/tunneldigger/broker/
mv ./l2tp_broker.cfg.example ./l2tp_broker.cfg
```
Configure as explained in config-file. The following hooks are used. They are linked in section `[hooks]`.
* Called after the tunnel interface goes up:
`session.up=/srv/tunneldigger/tunneldigger/broker/scripts/tunnel.up`
* Called after the tunnel interface goes down:
`session.down=/srv/tunneldigger/tunneldigger/broker/scripts/tunnel.down`

**Hook-Scripts:**
* tunnel.up
```
#!/bin/bash
TUNNEL_ID="$1"
INTERFACE="$3"
MTU="$4"
BATDEV=bat0
#BATDEV="$9"

. /srv/tunneldigger/tunneldigger/broker/scripts/bridge_functions

# Set the interface to UP state
ip link set dev $INTERFACE up mtu $MTU

# Add the interface to our bridge
ensure_bridge br-${BATDEV}-${MTU}
brctl addif br-${BATDEV}-${MTU} $INTERFACE
```
* tunnel.up - *test this hook with whitelist.txt-support*
```
#!/bin/bash
TUNNEL_ID="$1"
INTERFACE="$3"
MTU="$4"
BATDEV=bat0
UUID="$8"

log_message() {
    message="$1"
    logger -p 6 -t "Tunneldigger" "$message"
    echo "$message" | systemd-cat -p info -t "Tunneldigger"
    echo "$1" 1>&2
}

if /bin/grep -Fq $UUID /srv/tunneldigger/tunneldigger/broker/whitelist.txt; then
log_message "New client with UUID=$UUID connected, adding to br-${BATDEV}-${MTU} bridge interface"

	. /srv/tunneldigger/tunneldigger/broker/scripts/bridge_functions

	# Set the interface to UP state
	ip link set dev $INTERFACE up mtu $MTU

	# Add the interface to our bridge
	ensure_bridge br-${BATDEV}-${MTU}
	brctl addif br-${BATDEV}-${MTU} $INTERFACE
else
        log_message "New client with UUID=$UUID is not whitelisted, not adding to br-${BATDEV}-${MTU} bridge interface"
	
fi
```

* tunnel.down
```
#!/bin/bash
TUNNEL_ID="$1"
INTERFACE="$3"
MTU="$4"
BATDEV=bat0

# Remove the interface from our bridge
brctl delif br-${BATDEV}${MTU} $INTERFACE
```
* mtu_changed.sh
```
#!/bin/bash
TUNNEL_ID="$1"
INTERFACE="$3"
OLD_MTU="$4"
NEW_MTU="$5"
BATDEV=bat0

. /srv/tunneldigger/tunneldigger/broker/scripts/bridge_functions

# Remove interface from old bridge
brctl delif br-${BATDEV}-${OLD_MTU} $INTERFACE

# Change interface MTU
ip link set dev $INTERFACE mtu $NEW_MTU

# Add interface to new bridge
ensure_bridge br-${BATDEV}-${NEW_MTU}
brctl addif br-${BATDEV}-${NEW_MTU} $INTERFACE
```

* bridge_functions
```
ensure_bridge()
{
  local brname="$1"
  brctl addbr $brname 2>/dev/null 

  if [[ "$?" == "0" ]]; then
    # Bridge did not exist before, we have to initialize it
    # generate random MAC 
    local mac=$(hexdump -n5 -e'"06" 5/1 ":%02X"' /dev/urandom)
    ip link set dev $brname address $mac 
    ip link set dev $brname up
    # add new bridge to bat-device
    batctl -m $BATDEV if add $brname
    # Disable forwarding between bridge ports
    ebtables -A FORWARD --logical-in $brname -j DROP
  fi
}
```
* Systemd Unit
```
[Unit]
Description=tunneldigger tunnelling network daemon using l2tpv3
After=network.target auditd.service

[Service]
Type=simple
WorkingDirectory=/srv/tunneldigger/tunneldigger
ExecStart=/srv/tunneldigger/env_tunneldigger/bin/python -m tunneldigger_broker.main /srv/tunneldigger/tunneldigger/broker/l2tp_broker.cfg

KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
## ToDo
* Define and test process for clonig broker-configuration and test it.
Couldt be:
```
cd /srv/tunneldigger/tunneldigger/broker
mv scripts scripts.example
git clone https://github.com/h03e/tunneldigger-broker-ffoh.git
```
* Open port 4500 UDP
* Hardcode domain or adress for every broker into site.conf
