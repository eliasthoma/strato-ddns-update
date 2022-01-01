#!/bin/bash
#
#  ____  ____  _   _ ____    _   _ ____  ____    _  _____ _____   ____   ____ ____  ___ ____ _____ 
# |  _ \|  _ \| \ | / ___|  | | | |  _ \|  _ \  / \|_   _| ____| / ___| / ___|  _ \|_ _|  _ \_   _|
# | | | | | | |  \| \___ \  | | | | |_) | | | |/ _ \ | | |  _|   \___ \| |   | |_) || || |_) || |  
# | |_| | |_| | |\  |___) | | |_| |  __/| |_| / ___ \| | | |___   ___) | |___|  _ < | ||  __/ | |  
# |____/|____/|_| \_|____/   \___/|_|   |____/_/   \_\_| |_____| |____/ \____|_| \_\___|_|    |_|  
# V1.1
# 
# https://github.com/et1902/strato-ddns-update
#
# This script is updating your Strato AG (strato.de) dyndns-entries.
# First make sure dns utils are installed: sudo apt install dnsutils -y
# Copy the script to a loaction on your system.
# Create crontab entry:
# */15 * * * * /path-to-location/update-ddns.sh -6 -d <your-domain> -p <your-ddns-password> > /path-to-location/update-ddns.log
#

function usage()
{
    echo "Usage: $0 [-h] [-4] [-6] [-f] [-d] ddns-name [-p] ddns-password" >&2
    echo "       -4 Enable update of A record"
    echo "       -6 Enable update of AAAA record"
    echo "       -f Force update"
    echo "       -d Domain to update"
    echo "       -p Your ddns password"
    exit 1
}

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

while getopts 'h46fd:p:' OPTION; do
    case "$OPTION" in
        h)
            usage
            ;;
        4)
            IP4_ENABLED=true
            ;;
        6)
            IP6_ENABLED=true
            ;;
        f)  
            FORCE_UPDATE=true
            echo "Option -f enabled: DNS-Update will be forced!"
            ;;
        d)
            DOMAIN="$OPTARG"
            ;;
        p)
            PASSWORD="$OPTARG"
            ;;
        :)
            echo "Option -$OPTARG requires an argument."
            exit 1
            ;;
        *)
            usage
            ;;
    esac
done

IP4_DNS=`dig $DOMAIN a +short @1.1.1.1`
IP6_DNS=`dig $DOMAIN aaaa +short @1.1.1.1`
printf "Current DNS entries for %s: \n" $DOMAIN
printf "A    %s \n" $IP4_DNS
printf "AAAA %s \n\n" $IP6_DNS

IP4=`curl --ipv4 -s http://icanhazip.com/`
IP6=`curl --ipv6 -s http://ipv6.icanhazip.com`   
printf "System ip addresses: \n"
printf "IPv4 %s \n" $IP4
printf "IPv6 %s \n\n" $IP6


if [ $IP4_ENABLED ] && [ $IP6_ENABLED ]; 
then
    if [[ ! $FORCE_UPDATE && "$IP4" = "$IP4_DNS" && "$IP6" = "$IP6_DNS"  ]]; 
    then
        printf "Domain %s is already up to date. Aborting...\n" $DOMAIN
        exit 0
    else
        IP_STRING="$IP4,$IP6"
    fi

elif [ $IP4_ENABLED ]; 
then
    if [ ! $FORCE_UPDATE ] && [ "$IP4" = "$IP4_DNS" ]; 
    then
        printf "Domain %s is already up to date. Aborting...\n" $DOMAIN
        exit 0
    else
        IP_STRING="$IP4"
    fi

elif [ $IP6_ENABLED ]; 
then
    if [ ! $FORCE_UPDATE ] && [ "$IP6" = "$IP6_DNS" ]; 
    then
        printf "Domain %s is already up to date. Aborting...\n" $DOMAIN
        exit 0
    else
        IP_STRING="$IP6"
    fi
fi

mkdir -p /tmp/update-ddns

CURL_RESPONSE="/tmp/update-ddns/${DOMAIN//[.]/_}.txt"

curl --silent -o $CURL_RESPONSE -i "https://$DOMAIN:$PASSWORD@dyndns.strato.com/nic/update?hostname=$DOMAIN&myip=$IP_STRING"

DDNS_STATUS=`egrep -o -w 'badauth|good|nochg|abuse' $CURL_RESPONSE`

case $DDNS_STATUS in
    good)
        printf "Domain %s successfully updated.\n" $DOMAIN
        exit 0
        ;;
    nochg)
        printf "Domain %s was already up to date.\n" $DOMAIN
        exit 0
        ;;
    badauth)
        printf "Auth failed!\n"
        printf "Check your credentials.\n"
        exit 1
        ;;
    abuse)
        printf "Abuse reported!\n"
        printf "Take a rest and try again later.\n"
        exit 1
        ;;
esac
