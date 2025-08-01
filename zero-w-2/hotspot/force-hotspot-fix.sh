#!/bin/bash

# 🚨 Force Hotspot Fix - Aggressive approach to get hotspot working
echo "🚨 Force fixing hotspot configuration..."

# Kill any hanging processes
echo "💀 Killing any hanging processes..."
sudo pkill -f hostapd || true
sudo pkill -f dnsmasq || true
sudo pkill -f wpa_supplicant || true

# Force stop services with timeout
echo "⏸️  Force stopping services..."
timeout 10 sudo systemctl stop hostapd || sudo systemctl kill hostapd
timeout 10 sudo systemctl stop dnsmasq || sudo systemctl kill dnsmasq
timeout 10 sudo systemctl stop wpa_supplicant || sudo systemctl kill wpa_supplicant

# Disconnect from any Wi-Fi network
echo "📶 Disconnecting from Wi-Fi networks..."
sudo wpa_cli disconnect 2>/dev/null || true
sudo wpa_cli disable_network all 2>/dev/null || true

# Bring down the interface and reconfigure it
echo "🔧 Reconfiguring wlan0 interface..."
sudo ip link set wlan0 down
sleep 2

# Flush any existing IP addresses
sudo ip addr flush dev wlan0

# Bring interface back up
sudo ip link set wlan0 up
sleep 2

# Manually assign the static IP
echo "🌐 Assigning static IP 192.168.4.1..."
sudo ip addr add 192.168.4.1/24 dev wlan0

# Verify IP assignment
echo "📋 Current wlan0 configuration:"
ip addr show wlan0 | grep "inet "

# Restart dnsmasq first
echo "🚀 Starting dnsmasq..."
sudo systemctl start dnsmasq
sleep 2

# Check dnsmasq status
if sudo systemctl is-active dnsmasq >/dev/null; then
    echo "✅ dnsmasq is running"
else
    echo "❌ dnsmasq failed to start"
    sudo systemctl status dnsmasq --no-pager -l | tail -5
fi

# Start hostapd
echo "📡 Starting hostapd..."
sudo systemctl start hostapd
sleep 3

# Check hostapd status
if sudo systemctl is-active hostapd >/dev/null; then
    echo "✅ hostapd is running"
else
    echo "❌ hostapd failed to start"
    sudo systemctl status hostapd --no-pager -l | tail -5
fi

# Start web server
echo "🌐 Starting web server..."
sudo systemctl start hotspot-config
sleep 2

if sudo systemctl is-active hotspot-config >/dev/null; then
    echo "✅ web server is running"
else
    echo "❌ web server failed to start"
fi

echo ""
echo "📊 Final Status Check:"
echo "====================="
echo "🌐 Interface IP: $(ip addr show wlan0 | grep 'inet ' | awk '{print $2}' | head -1)"
echo "📡 HOSTAPD: $(sudo systemctl is-active hostapd)"
echo "🌐 DNSMASQ: $(sudo systemctl is-active dnsmasq)"
echo "🖥️  WEB SERVER: $(sudo systemctl is-active hotspot-config)"

echo ""
echo "🔍 Look for 'MyHotspot' network now!"
echo "🌐 Web interface: http://192.168.4.1"
