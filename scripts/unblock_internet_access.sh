#!/bin/bash

echo "Unblocking internet access..."

# Flush IPv4 rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Flush IPv6 rules
ip6tables -F
ip6tables -X

echo "Updating the timesyncd config"
# New configuration content
cat > /etc/systemd/timesyncd.conf <<EOF
[Time]
NTP=pool.ntp.org 0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org
FallbackNTP=time1.google.com time2.google.com time3.google.com time4.google.com
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF

# Restart timesyncd to apply changes
systemctl restart systemd-timesyncd

echo "Unblocked internet access and configured NTP!"
