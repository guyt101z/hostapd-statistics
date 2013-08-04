#!/bin/bash
#This script simply waits for stuff from Hostapd to appear in the syslog
loadcfg() {
#if we got no conf file define everything here.
wlandev="wlan0"
sleeptime="5m"
webinterfaceport="1500"
dhcpserverip="192.168.178.1"
use_sensors="0"
use_vnstat="0"
use_iw="0"

SCRIPT_FILE=$( readlink -f "${BASH_SOURCE[0]}" )
SCRIPT_DIR="${SCRIPT_FILE%/*}"
source "${SCRIPT_DIR}/CONFIG"
}
loadcfg
timeoutcheck() {
# This function removes devices which aren't connected anymore but also don't disconnect properly.
# It uses the iw tool to dump all connected clients.
while read -r line
do
	mac=`echo "$line" | cut -d";" -f1`
	iwcheck=`iw dev "$wlandev" station dump | grep -i "$mac"` 
	if [ -z "$iwcheck" ]; then
		sed -i -e "/$mac/d" ./conclients #remove the line with $mac from conclients
		echo "$mac timed out."
	fi
done < ./conclients
}
timeoutcheck_loop() { timeoutcheck; while sleep "$sleeptime"; do timeoutcheck; done; }
echo "Hostapd-statistics launched"
# Remove all old entrys and create the file if it doesn't exist.
> ./conclients
# Launch the webinterface listener. In comparison to netcat, this method runs web.sh only at access and not as soon as netcat is startet.
socat TCP4-LISTEN:"$webinterfaceport",fork,reuseaddr EXEC:"bash ${SCRIPT_DIR}/web.bash" & 
# Run the infinite loop
timeoutcheck_loop &
readonly TIMEOUTCHECK_PID=$!
trap "kill ${TIMEOUTCHECK_PID}" TERM EXIT
# The whole watch the syslog thingy
while :
do
	inotifywait -q -e modify /var/log/syslog && bash "${SCRIPT_DIR}/core.bash"
done

