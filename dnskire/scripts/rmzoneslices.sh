#!/bin/bash
# Example: ./rmzoneslices.sh hackers.com cdn

export BINDZONEDIR="/etc/bind/zones/"

if [ "$#" -ne 2 ]; then
    echo "Error: Missing arguments for removezone script!"
    echo "Example: ./rmzoneslices.sh hackers.com fonts.cdn"
    exit 2
fi
export domain=$1
export sub=$2

# remove the sub domain slices from the include zone file
sed -i "/^$sub\..*[ \t]*TXT[ \t]*/,/\")/d" $BINDZONEDIR$domain".inc"

echo -n "Removed"

# increment the soa serial and reload the zone
export curserial=$(grep -i serial $BINDZONEDIR"db."$domain | awk '{print $1}')
export newserial=$(echo $curserial | grep -i serial $BINDZONEDIR"db."$domain | sed -e 's/^\s*//g' | sed -r 's/(20[0-9]{3,8})(.*$)/echo `expr \1 + 1` "\2"/e' | awk '{print $1}')
sed -i "s/$curserial/$newserial/" $BINDZONEDIR"db."$domain

# reload the zone with rndc
rndc reload $domain >> /dev/null

echo -n "Zone file for $domain reloaded."
