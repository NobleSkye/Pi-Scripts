#!/bin/bash

set -e

echo "🛑 Stopping hotspot services..."
sudo systemctl stop hostapd dnsmasq

echo "⚙️ Restoring original dhcpcd.conf..."
if [ -f /etc/dhcpcd.conf.orig ]; then
  sudo mv /etc/dhcpcd.conf.orig /etc/dhcpcd.conf
else
  echo "⚠️ No backup dhcpcd.conf.orig found, creating minimal default..."
  cat <<EOF | sudo tee /etc/dhcpcd.conf >/dev/null
hostname
clientid
persistent
option rapid_commit
option domain_name_servers, domain_name, domain_search, host_name
option classless_static_routes
option interface_mtu
require dhcp_server_identifier
slaac private
EOF
fi

echo "⚙️ Restoring original dnsmasq.conf..."
if [ -f /etc/dnsmasq.conf.orig ]; then
  sudo mv /etc/dnsmasq.conf.orig /etc/dnsmasq.conf
else
  echo "⚠️ No backup dnsmasq.conf.orig found, creating empty config..."
  echo "" | sudo tee /etc/dnsmasq.conf >/dev/null
fi

echo "🛑 Disabling and stopping hostapd and dnsmasq services..."
sudo systemctl disable hostapd
sudo systemctl disable dnsmasq
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq

echo "🔁 Restarting dhcpcd service..."
sudo systemctl restart dhcpcd

echo "🔧 Restarting networking service..."
sudo systemctl restart networking || true

echo "🔧 Bringing wlan0 interface down and up..."
sudo ip link set wlan0 down
sudo ip link set wlan0 up

echo "🛠️ Re-enabling wpa_supplicant service..."
sudo systemctl unmask wpa_supplicant
sudo systemctl enable wpa_supplicant
sudo systemctl start wpa_supplicant

echo "🧹 Removing NAT iptables rules (if any)..."
sudo iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
sudo rm -f /etc/iptables.ipv4.nat

if grep -q "iptables-restore" /etc/rc.local 2>/dev/null; then
  sudo sed -i '/iptables-restore/d' /etc/rc.local
fi

echo "✅ Network reset complete. Please reboot your Pi."
