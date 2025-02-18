#!/bin/sh

cidr2mask() {
   # Number of args to shift, 255..255, first non-255 byte, zeroes
   set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
   [ $1 -gt 1 ] && shift "$1" || shift
   echo ${1-0}.${2-0}.${3-0}.${4-0}
}

cidr2net() {
    local i ip mask netOctets octets
    ip="${1%/*}"
    mask="${1#*/}"
    octets=$(echo "$ip" | tr '.' '\n')

    for octet in $octets; do
        i=$((i+1))
        if [ $i -le $(( mask / 8)) ]; then
            netOctets="$netOctets.$octet"
        elif [ $i -eq  $(( mask / 8 +1 )) ]; then
            netOctets="$netOctets.$((((octet / ((256 / ((2**((mask % 8)))))))) * ((256 / ((2**((mask % 8))))))))"
        else
            netOctets="$netOctets.0"
        fi
    done

    echo ${netOctets#.}
}

/etc/openvpn/setup/setup-certs.sh
iptables -t nat -A POSTROUTING -s ${OVPN_NETWORK}/${OVPN_SUBNET_MASK} -o eth0 -j MASQUERADE
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

intAndIP="$(ip route get 8.8.8.8 | awk '/8.8.8.8/ {print $5 "-" $7}')"
int="${intAndIP%-*}"
ip="${intAndIP#*-}"
cidr="$(ip addr show dev "$int" | awk -vip="$ip" '($2 ~ ip) {print $2}')"

NETWORK="$(cidr2net $cidr)"
NETMASK="$(cidr2mask ${cidr#*/})"
DNS=$(cat /etc/resolv.conf | grep -v '^#' | grep nameserver | awk '{print $2}')
SEARCH=$(cat /etc/resolv.conf | grep -v '^#' | grep search | awk '{$1=""; print $0}')
FORMATTED_SEARCH=""
for DOMAIN in $SEARCH; do
  FORMATTED_SEARCH="${FORMATTED_SEARCH}push \"dhcp-option DOMAIN-SEARCH ${DOMAIN}\"\n"
done
cp -f /etc/openvpn/setup/openvpn.conf /etc/openvpn/
sed 's|OVPN_NETWORK|'"${OVPN_NETWORK}"'|' -i /etc/openvpn/openvpn.conf
sed 's|OVPN_SUBNET_MASK|'"${OVPN_SUBNET_MASK}"'|' -i /etc/openvpn/openvpn.conf
sed 's|CIPHER|'"${CIPHER}"'|' -i /etc/openvpn/openvpn.conf

sed 's|OVPN_K8S_POD_NETWORK|'"${OVPN_K8S_POD_NETWORK}"'|' -i /etc/openvpn/openvpn.conf
sed 's|OVPN_K8S_POD_SUBNET_MASK|'"${OVPN_K8S_POD_SUBNET_MASK}"'|' -i /etc/openvpn/openvpn.conf
sed 's|OVPN_K8S_SVC_NETWORK|'"${OVPN_K8S_SVC_NETWORK}"'|' -i /etc/openvpn/openvpn.conf
sed 's|OVPN_K8S_SVC_SUBNET_MASK|'"${OVPN_K8S_SVC_SUBNET_MASK}"'|' -i /etc/openvpn/openvpn.conf

sed 's|NETWORK|'"${NETWORK}"'|' -i /etc/openvpn/openvpn.conf
sed 's|NETMASK|'"${NETMASK}"'|' -i /etc/openvpn/openvpn.conf

sed 's|OVPN_K8S_SEARCH|'"${FORMATTED_SEARCH}"'|' -i /etc/openvpn/openvpn.conf
sed 's|OVPN_K8S_DNS|'"${DNS}"'|' -i /etc/openvpn/openvpn.conf

openvpn --config /etc/openvpn/openvpn.conf
