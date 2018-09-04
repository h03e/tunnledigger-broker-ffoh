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
