#!/bin/bash

echo "Blocking internet access..."

# -----------------------------------------------------------------------------------------------------
# 1. Flush existing rules to avoid accumulation and deadlocks
# -----------------------------------------------------------------------------------------------------
echo "Flushing existing rules..."
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
ip6tables -F
ip6tables -X

# Set default policies to DROP (we will explicitly allow what we need)
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP
ip6tables -P INPUT DROP
ip6tables -P OUTPUT DROP
ip6tables -P FORWARD DROP

# -----------------------------------------------------------------------------------------------------
# 2. Basic Connectivity (Loopback & Established)
# -----------------------------------------------------------------------------------------------------
echo "Configuring basic connectivity..."
# Allow local loopback
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
ip6tables -A INPUT  -i lo -j ACCEPT
ip6tables -A OUTPUT -o lo -j ACCEPT

# Allow established/related traffic globally
iptables -A INPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -A INPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow ICMP (ping) for diagnostics
iptables -A INPUT  -p icmp -j ACCEPT
iptables -A OUTPUT -p icmp -j ACCEPT
ip6tables -A INPUT  -p ipv6-icmp -j ACCEPT
ip6tables -A OUTPUT -p ipv6-icmp -j ACCEPT

# -----------------------------------------------------------------------------------------------------
# 3. LAN Traffic (Allow everything on local network)
# -----------------------------------------------------------------------------------------------------
echo "Allowing LAN traffic..."
# IPv4 LAN Classes
iptables -A INPUT  -s 10.0.0.0/8     -j ACCEPT
iptables -A OUTPUT -d 10.0.0.0/8     -j ACCEPT
iptables -A INPUT  -s 172.16.0.0/12  -j ACCEPT
iptables -A OUTPUT -d 172.16.0.0/12  -j ACCEPT
iptables -A INPUT  -s 192.168.0.0/16 -j ACCEPT
iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT

# IPv6 LAN (Link-local and Unique-local)
ip6tables -A INPUT  -s fe80::/10 -j ACCEPT
ip6tables -A OUTPUT -d fe80::/10 -j ACCEPT
ip6tables -A INPUT  -s fd00::/8  -j ACCEPT
ip6tables -A OUTPUT -d fd00::/8  -j ACCEPT

# -----------------------------------------------------------------------------------------------------
# 4. Critical Services (DNS & NTP)
# -----------------------------------------------------------------------------------------------------
echo "Allowing DNS and NTP..."
# Allow DNS (IPv4 & IPv6)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
ip6tables -A OUTPUT -p udp --dport 53 -j ACCEPT
ip6tables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow NTP (IPv4 & IPv6)
iptables -A OUTPUT -p udp --dport 123 -j ACCEPT
ip6tables -A OUTPUT -p udp --dport 123 -j ACCEPT

# -----------------------------------------------------------------------------------------------------
# 5. Sentry Logging (Optional)
# -----------------------------------------------------------------------------------------------------
if [ "${ALLOW_SENTRY:-true}" != "false" ]; then
  echo "Allowing Sentry error logging..."
  SENTRY_IPS=("35.186.247.156" "34.120.195.249" "34.36.122.224" "34.36.87.148" "34.120.62.213" "130.211.36.74")
  for ip in "${SENTRY_IPS[@]}"; do
    iptables -A OUTPUT -d "$ip" -j ACCEPT
  done
fi

# -----------------------------------------------------------------------------------------------------
# 6. Save Rules
# -----------------------------------------------------------------------------------------------------
mkdir -p /etc/iptables
iptables-save > /etc/iptables/iptables.rules
ip6tables-save > /etc/iptables/ip6tables.rules

# -----------------------------------------------------------------------------------------------------
# 7. Time Synchronization & Hardware Persistence
# -----------------------------------------------------------------------------------------------------
echo "Updating the timesyncd config..."
cat > /etc/systemd/timesyncd.conf <<EOF
[Time]
NTP=pool.ntp.org 0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org
FallbackNTP=time1.google.com time2.google.com time3.google.com time4.google.com
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF

systemctl restart systemd-timesyncd
timedatectl set-ntp true

echo "Waiting for system clock synchronization (up to 30s)..."
for i in {1..30}; do
  if timedatectl status | grep -q "System clock synchronized: yes"; then
    echo "Clock synchronized!"
    break
  fi
  sleep 1
done

# --- PERSISTENCE SAFETY CHECK ---
# Never persist a 2010/2022 reset to the hardware clock.
# Only update the RTC if the current system year is sane (>= 2024).
CURRENT_YEAR=$(date +%Y)
if [ "$CURRENT_YEAR" -ge 2024 ]; then
  echo "System year ($CURRENT_YEAR) is valid. Persisting to hardware clock..."
  hwclock --systohc
else
  echo -e "\033[0;31mWARNING: System time ($CURRENT_YEAR) is still incorrect. SKIPPING hardware clock update.\033[0m"
fi

echo "Firewall and time sync configuration complete!"

