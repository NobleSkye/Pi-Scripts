#!/bin/bash

# 🔄 Network Restore Script - Get back online
echo "🔄 Restoring normal Wi-Fi connection..."

# Stop all hotspot services
echo "⏸️  Stopping hotspot services..."
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo systemctl stop hotspot-config 2>/dev/null || true

# Kill any processes that might interfere
sudo pkill -f hostapd || true
sudo pkill -f dnsmasq || true

# Disable hotspot services temporarily
echo "🚫 Disabling hotspot services..."
sudo systemctl disable hostapd 2>/dev/null || true
sudo systemctl disable dnsmasq 2>/dev/null || true

# Reset wlan0 interface
echo "🔧 Resetting wlan0 interface..."
sudo ip link set wlan0 down
sudo ip addr flush dev wlan0
sudo ip link set wlan0 up

# Restore default dhcpcd.conf for normal Wi-Fi
echo "📝 Restoring normal dhcpcd configuration..."
sudo tee /etc/dhcpcd.conf << 'EOF'
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

# Restart dhcpcd to apply normal DHCP
echo "🔄 Restarting dhcpcd..."
sudo systemctl restart dhcpcd

# Start wpa_supplicant for Wi-Fi client mode
echo "📶 Starting Wi-Fi client services..."
sudo systemctl enable wpa_supplicant
sudo systemctl start wpa_supplicant

# Try to reconnect to known networks
echo "🔗 Attempting to reconnect to Wi-Fi..."
sudo wpa_cli reconfigure
sleep 5

# Check connection
echo "📋 Checking network status..."
ip addr show wlan0 | grep "inet "

# Test connectivity
echo "🌐 Testing internet connectivity..."
if ping -c 1 google.com >/dev/null 2>&1; then
    echo "✅ Internet connection restored!"
    echo "🌐 Current IP: $(ip addr show wlan0 | grep 'inet ' | awk '{print $2}' | head -1)"
else
    echo "❌ Still no internet. Manual Wi-Fi setup may be needed."
    echo ""
    echo "📋 Try these commands manually:"
    echo "   sudo raspi-config  # Configure Wi-Fi"
    echo "   sudo reboot        # Restart system"
fi

echo ""
echo "🔧 To set up hotspot later, run:"
echo "   curl -fsSL https://raw.githubusercontent.com/NobleSkye/Pi-Scripts/main/Zero-2-w/hotspot/setup-hotspot.sh | bash"
