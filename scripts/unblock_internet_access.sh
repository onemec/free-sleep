#!/bin/bash

echo "Unblocking internet access..."

iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT

ip6tables -F
ip6tables -X
ip6tables -P INPUT ACCEPT
ip6tables -P OUTPUT ACCEPT
ip6tables -P FORWARD ACCEPT

echo "Unblocked internet access!"
