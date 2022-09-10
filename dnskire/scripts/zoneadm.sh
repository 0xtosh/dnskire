#!/bin/bash
# Example: ./zoneadm.sh [search | add | remove] domain.tld

export BINDDIR="/etc/bind/"
export BINDZONEDIR="/etc/bind/zones/"

usage () {
    echo "Error: Missing or wrong arguments for zoneadm script!"
    echo "Example: ./zoneadm.sh [ search | add | remove ] domain.tld"
    exit 2
}

if [ "$#" -ne 2 ]; then
    usage
fi

export ACTION=$1

if [ "$ACTION" != "search" ] && [ "$ACTION" != "add" ] && [ "$ACTION" != "remove" ]; then
    usage
fi

export DOMAIN=$2

havedomain () {
    # find
    export SEARCHDOMAIN=$1
    export CHECKDOMAIN=$(grep "zone \"${SEARCHDOMAIN}\"" ${BINDDIR}/named.conf.local)
    if [ "$CHECKDOMAIN" == "" ]; then
       echo 0
    else
       echo 1
    fi
}

if [ "$ACTION" == "search" ]; then
    export ret=$(havedomain "$DOMAIN")
    if [ "$ret" == "1" ]; then
       echo "got it"
    else
       echo "dont got it"
    fi

elif [ "$ACTION" == "add" ]; then

    export ZONEFILE=${BINDZONEDIR}db.${DOMAIN}
    export IP=$(/usr/bin/hostname -I | awk '{print $1}' | /usr/bin/tr -d ' \n')
    export CURDATE=$(/usr/bin/date +"%Y%m%d00" | /usr/bin/tr -d '\n')

    # add zone file reference
    echo "Adding ${DOMAIN} entry in named.conf.local"

    export dowehaveit=$(grep "zone \"${DOMAIN}\"" '/etc/bind/named.conf.local')
    if [ "$dowehaveit" = "" ]; then
      echo "zone \"${DOMAIN}\" { type master; file \"/etc/bind/zones/db.${DOMAIN}\"; };" >> "${BINDDIR}/named.conf.local"
    fi

    echo "\$TTL    300
@       IN      SOA     ns1.${DOMAIN}. admin.${DOMAIN}. (
${CURDATE}   ; Serial
604800     ; Refresh
86400     ; Retry
2419200     ; Expire
604800 )   ; Negative Cache TTL" >> $ZONEFILE
    echo "
    ;NS records
	IN      NS      ns1.${DOMAIN}.
    	IN      NS      ns2.${DOMAIN}.
    ;A records
ns1.${DOMAIN}.          IN      A       $IP
ns2.${DOMAIN}.          IN      A       $IP
www.${DOMAIN}.          IN      A       $IP

\$INCLUDE \"/etc/bind/zones/${DOMAIN}.inc\";" >> $ZONEFILE

    touch ${BINDZONEDIR}${DOMAIN}.inc 


elif [ "$ACTION" == "remove" ]; then

    export ZONEFILE=${BINDZONEDIR}db.${DOMAIN}

    # remove
    echo "Removing ${DOMAIN} zone file"
    rm $ZONEFILE

    export RMCMD=$(sed -i "s/^zone \"${DOMAIN}\".*$//" ${BINDDIR}/named.conf.local)
    if [ "$RMCMD" == "" ]; then
       echo "Removed ${DOMAIN} from named.conf.local"
    else
       echo "Failed to remove ${DOMAIN} from named.conf.local!"
    fi

else
    usage
fi


