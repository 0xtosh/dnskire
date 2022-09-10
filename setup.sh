#!/bin/bash
# dnsKIRE quick and dirty best effort setup script
#
# This script was tested and should run flawlessly on a new Ubuntu 22.04.1 LTS (Jammy Jellyfish)
#
#  1. Add the user "dnskire"
#  2. Add the user to /etc/sudoers with: dnskire ALL=(ALL:ALL) NOPASSWD: ALL
#  3. Run this script as user "dnskire" to install dependencies
#
#
#
if [[ "$USER" != "dnskire" ]]; then
   echo "Add a user \"dnskire\", log in as \"dnskire\" and run this script again. Exiting."
   exit 1
fi

if [[ $(sudo -l -U dnskire | grep -A1 "dnskire may") != *"(ALL : ALL) NOPASSWD: ALL"* ]]; then 
   echo "dnskire is not in /etc/sudoers!"
   echo
   echo "Add this line to /etc/sudoers as root and rerun this script as \"dnskire\":"
   echo
   echo " dnskire ALL=(ALL:ALL) NOPASSWD: ALL"
   echo
   echo "Exiting."
   exit 1
fi

CHKFILE="dnskire/certs/dnsKIRE.local.key"

if test -f "$CHKFILE"; then
    echo
    echo "WARNING: You seem to have already installed dnsKIRE!"
    echo 
    echo "Re-running this script will trash your installation!" 
    echo
    echo "If you want to continue you will have to click on \"Reset All\" in the web interface afterwards."
    echo
    read -p "Are you sure you want to continue? " -n 1 -r
    echo    
    if [[ ! $REPLY =~ ^[Yy]$ ]]
       then
         echo "Exiting..."
         exit 0
    else
        echo "Continuing..."
    fi
fi


# auto restart services if needed
echo "\$nrconf{restart} = 'a';" | sudo tee -a /etc/needrestart/needrestart.conf

echo "Installing required packages..."
sudo apt-get update
sudo apt-get -y install nodejs bind9 bind9-host file bind9-dnsutils sqlite3 vim sed coreutils npm screen exiftool

echo "Changing permissions..."
# add the dnskire user to the bind group
sudo usermod -a -G bind dnskire
sudo chown -R dnskire:bind dnskire
sudo chmod -R 775 dnskire/scripts/*.sh

echo "Creating zone directories..."
sudo mkdir /etc/bind/zones/
sudo chmod -R 775 /etc/bind/zones/
sudo chown dnskire:bind /etc/bind/zones/

echo "Renaming and replacing bind configuration files..."
sudo mv /etc/bind/named.conf /etc/bind/named.conf.dnskire-renamed
sudo mv /etc/bind/named.conf.options /etc/bind/named.conf.options.dnskire-renamed
sudo mv /etc/bind/named.conf.local /etc/bind/named.conf.local.dnskire-renamed
sudo touch /etc/bind/named.conf.local
sudo chown dnskire:bind /etc/bind/named.conf.local
sudo chmod 774 /etc/bind/named.conf.local
sudo chmod g+w /etc/bind

echo "Replacing named.conf..."
sudo echo "include \"/etc/bind/named.conf.options\";
include \"/etc/bind/named.conf.local\";
include \"/etc/bind/rndc.key\";
include \"/etc/bind/named.conf.default-zones\";" | sudo tee -a /etc/bind/named.conf

echo "Replacing named.conf.options..."
sudo echo "options {
        directory \"/var/cache/bind\";
        dnssec-validation auto;
        listen-on { any; };
        querylog yes;
};
logging {
        channel querylog {
                file \"/var/log/named/query.log\";
                severity debug 3;
        };
};"  | sudo tee -a /etc/bind/named.conf.options


sudo mkdir /var/log/named
sudo touch /var/log/named/query.log
sudo chown bind:bind /var/log/named/query.log
sudo chmod 775 /var/log/named/query.log

echo "Generating RNDC key for bind interaction..."
# generate the rndc key so the dnskire account can reload a domain or the entire config
sudo rndc-confgen -a -k dnskire
sudo chown bind:dnskire /etc/bind/rndc.key
sudo chmod 440 /etc/bind/rndc.key
sudo echo "controls {
    inet 127.0.0.1 port 953
       allow { 127.0.0.1; } keys { \"dnskire\"; };
};" | sudo tee -a /etc/bind/named.conf

sudo chown dnskire:bind /etc/bind/named.conf*
sudo service bind9 restart

echo "Generating TLS self-signed certificate... (Replace with your own)"
# generate the cert for tls
export IP=$(/usr/bin/hostname -I | awk '{print $1}' | /usr/bin/tr -d ' \n')
sudo openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout dnskire/certs/dnsKIRE.local.key -out dnskire/certs/dnsKIRE.local.crt -subj "/CN=dnsKIRE.local" -addext "subjectAltName=DNS:dnsKIRE.local,DNS:dnsKIRE.local,IP:$IP"
sudo chown dnskire:bind dnskire/certs/*

cd dnskire
export NPMS="node-gyp is-alphanumeric uuid express url is-valid-domain cors body-parser filesize express-fileupload sqlite3 fs path"
for npmmodule in $(echo $NPMS | tr ' ' '\n'); 
do 
   sudo npm install $npmmodule
done

echo 
echo "Done!"
echo 
echo "To run as user \"dnskire\" from the dnskire/ directory:"
echo
echo "\$ node dnskire.js"
echo 
echo "Or run from a screen: \"screen -S dnskire -d -m node dnskire.js\""


