#!/bin/bash

set -e

echo "🛠️  Updating and installing required packages..."
sudo apt update
sudo apt install -y hostapd dnsmasq dhcpcd5 iptables

# Prompt for user input
read -p "📶 Enter Wi-Fi SSID (network name): " ssid
read -s -p "🔑 Enter Wi-Fi password (min 8 characters): " wifi_password
echo
read -p "🌐 Enter static IP for Pi's Wi-Fi (default: 192.168.4.1): " static_ip
static_ip=${static_ip:-192.168.4.1}

read -p "📦 Enter DHCP range start (default: 192.168.4.2): " dhcp_start
dhcp_start=${dhcp_start:-192.168.4.2}

read -p "📦 Enter DHCP range end (default: 192.168.4.20): " dhcp_end
dhcp_end=${dhcp_end:-192.168.4.20}

read -p "🔁 Enable internet sharing from eth0 to Wi-Fi clients? (y/N): " enable_nat

echo "⏸️  Stopping services..."
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq

echo "📝 Configuring dhcpcd..."
sudo cp /usr/share/dhcpcd5/dhcpcd.conf /etc/dhcpcd.conf

# Append static IP config
cat <<EOF | sudo tee -a /etc/dhcpcd.conf

interface wlan0
    static ip_address=${static_ip}/24
    nohook wpa_supplicant
EOF

sudo systemctl restart dhcpcd

echo "🌐 Configuring dnsmasq..."
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig || true
cat <<EOF | sudo tee /etc/dnsmasq.conf
interface=wlan0
dhcp-range=${dhcp_start},${dhcp_end},255.255.255.0,24h
EOF

echo "📡 Configuring hostapd..."
sudo mkdir -p /etc/hostapd
cat <<EOF | sudo tee /etc/hostapd/hostapd.conf
interface=wlan0
driver=nl80211
ssid=${ssid}
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${wifi_password}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

sudo sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

echo "📶 Enabling services..."
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq

# Internet sharing setup (optional)
if [[ "$enable_nat" =~ ^[Yy]$ ]]; then
  echo "🌍 Setting up NAT for internet sharing..."
  echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
  sudo sysctl -w net.ipv4.ip_forward=1
  sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
  sudo sed -i '/^exit 0/i iptables-restore < /etc/iptables.ipv4.nat' /etc/rc.local
fi

echo "✅ Hotspot setup complete. Rebooting..."
sudo reboot
