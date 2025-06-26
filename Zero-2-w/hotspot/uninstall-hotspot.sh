#!/bin/bash

# 🗑️ Raspberry Pi Hotspot Uninstall Script
# 
# This script removes the hotspot configuration and restores the system
# to its original networking state.
#
# Usage: 
#   ./uninstall-hotspot.sh
#   curl -fsSL <url> | bash
#
# What it does:
# - Stops and disables hotspot services
# - Removes configuration files
# - Restores original network configs
# - Removes web configuration interface
# - Cleans up iptables rules

set -e

echo "🗑️ Raspberry Pi Hotspot Uninstaller"
echo "=================================="
echo ""

# Check if running as root or with sudo
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Please run this script as a regular user with sudo access, not as root"
    exit 1
fi

# Confirm uninstall
echo "⚠️  This will:"
echo "   • Stop and disable hostapd and dnsmasq services"
echo "   • Remove hotspot configuration files"
echo "   • Restore original network configuration"
echo "   • Remove web configuration interface"
echo "   • Clean up firewall rules"
echo "   • Remove installed packages (optional)"
echo ""

# Handle input for both interactive and piped execution
if [ -t 0 ]; then
    read -p "🤔 Are you sure you want to uninstall the hotspot? (y/N): " confirm
else
    read -p "🤔 Are you sure you want to uninstall the hotspot? (y/N): " confirm < /dev/tty
fi

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ Uninstall cancelled"
    exit 0
fi

echo ""
echo "🛑 Stopping hotspot services..."

# Stop services
sudo systemctl stop hostapd 2>/dev/null || echo "   • hostapd not running"
sudo systemctl stop dnsmasq 2>/dev/null || echo "   • dnsmasq not running"
sudo systemctl stop hotspot-config 2>/dev/null || echo "   • hotspot-config not running"

# Disable services
echo "🚫 Disabling hotspot services..."
sudo systemctl disable hostapd 2>/dev/null || echo "   • hostapd not enabled"
sudo systemctl disable dnsmasq 2>/dev/null || echo "   • dnsmasq not enabled"
sudo systemctl disable hotspot-config 2>/dev/null || echo "   • hotspot-config not enabled"
sudo systemctl disable iptables-restore 2>/dev/null || echo "   • iptables-restore not enabled"

echo "🗂️ Removing configuration files..."

# Remove hotspot configurations
sudo rm -f /etc/hostapd/hostapd.conf
sudo rm -f /etc/systemd/system/hotspot-config.service
sudo rm -f /etc/systemd/system/iptables-restore.service

# Restore original configurations if backups exist
echo "🔄 Restoring original configurations..."

# Find the most recent backup
LATEST_BACKUP=$(sudo find /opt/hotspot-backup -name "20*" -type d 2>/dev/null | sort | tail -1)

if [ -n "$LATEST_BACKUP" ] && [ -d "$LATEST_BACKUP" ]; then
    echo "   📁 Found backup: $LATEST_BACKUP"
    
    # Restore dhcpcd.conf
    if [ -f "$LATEST_BACKUP/dhcpcd.conf" ]; then
        sudo cp "$LATEST_BACKUP/dhcpcd.conf" /etc/dhcpcd.conf
        echo "   ✅ Restored /etc/dhcpcd.conf"
    fi
    
    # Restore dnsmasq.conf
    if [ -f "$LATEST_BACKUP/dnsmasq.conf" ]; then
        sudo cp "$LATEST_BACKUP/dnsmasq.conf" /etc/dnsmasq.conf
        echo "   ✅ Restored /etc/dnsmasq.conf"
    elif [ -f /etc/dnsmasq.conf.orig ]; then
        sudo mv /etc/dnsmasq.conf.orig /etc/dnsmasq.conf
        echo "   ✅ Restored /etc/dnsmasq.conf from .orig"
    fi
else
    echo "   ⚠️  No backup found, creating default configurations..."
    
    # Create minimal dhcpcd.conf
    cat <<EOF | sudo tee /etc/dhcpcd.conf >/dev/null
# A sample configuration for dhcpcd.
# See dhcpcd.conf(5) for details.

# Allow users of this group to interact with dhcpcd via the control socket.
#controlgroup wheel

# Inform the DHCP server of our hostname for DDNS.
hostname

# Use the hardware address of the interface for the Client ID.
clientid

# Persist interface configuration when dhcpcd exits.
persistent

# Rapid commit support.
# Safe to enable by default because it requires the equivalent option set
# on the server to actually work.
option rapid_commit

# A list of options to request from the DHCP server.
option domain_name_servers, domain_name, domain_search, host_name
option classless_static_routes

# Respect the network MTU. This is applied to DHCP routes.
option interface_mtu

# Most distributions have NTP support.
#option ntp_servers

# A ServerID is required by RFC2131.
require dhcp_server_identifier

# Generate SLAAC address using the Hardware Address of the interface
#slaac hwaddr
# OR generate Stable Private IPv6 Addresses based on the DUID
slaac private
EOF
    echo "   ✅ Created default /etc/dhcpcd.conf"
    
    # Restore default dnsmasq.conf if original exists
    if [ -f /etc/dnsmasq.conf.orig ]; then
        sudo mv /etc/dnsmasq.conf.orig /etc/dnsmasq.conf
        echo "   ✅ Restored /etc/dnsmasq.conf from .orig"
    else
        sudo rm -f /etc/dnsmasq.conf
        echo "   ✅ Removed /etc/dnsmasq.conf"
    fi
fi

# Reset hostapd daemon config
echo "🔧 Resetting hostapd configuration..."
sudo sed -i 's|DAEMON_CONF="/etc/hostapd/hostapd.conf"|#DAEMON_CONF=""|' /etc/default/hostapd 2>/dev/null || true

# Clean up IP forwarding
echo "🌐 Cleaning up IP forwarding..."
sudo sed -i '/net.ipv4.ip_forward=1/d' /etc/sysctl.conf 2>/dev/null || true
sudo sysctl -w net.ipv4.ip_forward=0 2>/dev/null || true

# Clean up iptables rules
echo "🔥 Cleaning up firewall rules..."
sudo iptables -t nat -F 2>/dev/null || true
sudo iptables -t nat -X 2>/dev/null || true
sudo rm -f /etc/iptables.ipv4.nat

# Remove web configuration interface
echo "🌐 Removing web configuration interface..."
sudo rm -rf /opt/hotspot-config

# Restart networking services
echo "🔄 Restarting networking services..."
sudo systemctl restart dhcpcd
sudo systemctl restart networking 2>/dev/null || true

# Reload systemd
sudo systemctl daemon-reload

echo ""
echo "🧹 Cleanup options:"
if [ -t 0 ]; then
    read -p "🗂️ Remove backup files? (y/N): " remove_backups
else
    read -p "🗂️ Remove backup files? (y/N): " remove_backups < /dev/tty
fi

if [[ "$remove_backups" =~ ^[Yy]$ ]]; then
    sudo rm -rf /opt/hotspot-backup
    echo "   ✅ Removed backup files"
fi

if [ -t 0 ]; then
    read -p "📦 Remove installed packages (hostapd, dnsmasq, flask)? (y/N): " remove_packages
else
    read -p "📦 Remove installed packages (hostapd, dnsmasq, flask)? (y/N): " remove_packages < /dev/tty
fi

if [[ "$remove_packages" =~ ^[Yy]$ ]]; then
    echo "   🗑️ Removing packages..."
    sudo apt remove --purge -y hostapd dnsmasq 2>/dev/null || true
    sudo pip3 uninstall -y flask 2>/dev/null || true
    sudo apt autoremove -y 2>/dev/null || true
    echo "   ✅ Packages removed"
fi

echo ""
echo "✅ Hotspot uninstall complete!"
echo ""
echo "📋 Summary of changes:"
echo "   • Hotspot services stopped and disabled"
echo "   • Configuration files removed/restored"
echo "   • Network settings restored to defaults"
echo "   • Web interface removed"
echo "   • Firewall rules cleaned"
echo ""
echo "🔄 System will reboot in 10 seconds to apply all changes..."
echo "   Press Ctrl+C to cancel reboot"

sleep 10
sudo reboot
