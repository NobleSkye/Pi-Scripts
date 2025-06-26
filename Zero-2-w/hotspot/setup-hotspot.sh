#!/bin/bash

# 🔧 Raspberry Pi Hotspot Setup Script
# 
# The script will always prompt for input unless environment variables are set.
# 
# Usage: 
#   ./setup-hotspot.sh                    - Interactive prompts
#   curl -fsSL <url> | bash               - Interactive prompts via terminal
#
# Skip prompts by setting environment variables:
#   HOTSPOT_SSID="MyHotspot" HOTSPOT_PASSWORD="mypass123" curl -fsSL <url> | bash
#
# Environment variables:
#   HOTSPOT_SSID     - Wi-Fi network name
#   HOTSPOT_PASSWORD - Wi-Fi password (min 8 characters)
#   HOTSPOT_IP       - Static IP address (default: 192.168.4.1)
#   DHCP_START       - DHCP range start (default: 192.168.4.2)
#   DHCP_END         - DHCP range end (default: 192.168.4.20)
#   ENABLE_NAT       - Enable internet sharing (y/N)

set -e

echo "🛠️  Updating and installing required packages..."
sudo apt update
sudo apt install -y hostapd dnsmasq dhcpcd5 iptables python3 python3-pip

# Install Python web framework
sudo pip3 install flask --break-system-packages

# 📋 Show current configuration if it exists
if [ -f /etc/hostapd/hostapd.conf ]; then
    echo ""
    echo "📋 Current Configuration Detected:"
    current_ssid=$(grep "^ssid=" /etc/hostapd/hostapd.conf 2>/dev/null | cut -d'=' -f2 || echo "Unknown")
    current_ip=$(grep "static ip_address=" /etc/dhcpcd.conf 2>/dev/null | cut -d'=' -f2 | cut -d'/' -f1 | xargs || echo "Unknown")
    current_dhcp=$(grep "^dhcp-range=" /etc/dnsmasq.conf 2>/dev/null | cut -d'=' -f2 || echo "Unknown")
    
    echo "   📶 Current SSID: $current_ssid"
    echo "   🌐 Current IP: $current_ip"
    echo "   📦 Current DHCP: $current_dhcp"
    echo ""
fi

# Force interactive input by redirecting from /dev/tty
exec < /dev/tty

# 🧠 Prompt for user input
if [ -z "$HOTSPOT_SSID" ]; then
    read -p "📶 Enter Wi-Fi SSID (new network name): " ssid
else
    ssid="$HOTSPOT_SSID"
    echo "📶 Using SSID: $ssid"
fi

if [ -z "$HOTSPOT_PASSWORD" ]; then
    read -s -p "🔑 Enter Wi-Fi password (min 8 characters): " wifi_password
    echo
else
    wifi_password="$HOTSPOT_PASSWORD"
    echo "🔑 Using provided password"
fi

if [ -z "$HOTSPOT_IP" ]; then
    read -p "🌐 Enter static IP for Pi's Wi-Fi (default: 192.168.4.1): " static_ip
    static_ip=${static_ip:-192.168.4.1}
else
    static_ip="$HOTSPOT_IP"
    echo "🌐 Using static IP: $static_ip"
fi

if [ -z "$DHCP_START" ]; then
    read -p "📦 Enter DHCP range start (default: 192.168.4.2): " dhcp_start
    dhcp_start=${dhcp_start:-192.168.4.2}
else
    dhcp_start="$DHCP_START"
    echo "📦 Using DHCP start: $dhcp_start"
fi

if [ -z "$DHCP_END" ]; then
    read -p "📦 Enter DHCP range end (default: 192.168.4.20): " dhcp_end
    dhcp_end=${dhcp_end:-192.168.4.20}
else
    dhcp_end="$DHCP_END"
    echo "📦 Using DHCP end: $dhcp_end"
fi

if [ -z "$ENABLE_NAT" ]; then
    read -p "🔁 Enable internet sharing from eth0 to Wi-Fi clients? (y/N): " enable_nat
else
    enable_nat="$ENABLE_NAT"
    echo "🔁 Internet sharing: $enable_nat"
fi

echo "⏸️  Stopping services..."
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true

# 💾 Backup existing configurations
echo "💾 Backing up existing configurations..."
BACKUP_DIR="/opt/hotspot-backup/$(date +%Y%m%d_%H%M%S)"
sudo mkdir -p "$BACKUP_DIR"

# Backup config files if they exist
[ -f /etc/hostapd/hostapd.conf ] && sudo cp /etc/hostapd/hostapd.conf "$BACKUP_DIR/"
[ -f /etc/dhcpcd.conf ] && sudo cp /etc/dhcpcd.conf "$BACKUP_DIR/"
[ -f /etc/dnsmasq.conf ] && sudo cp /etc/dnsmasq.conf "$BACKUP_DIR/"
[ -f /etc/iptables.ipv4.nat ] && sudo cp /etc/iptables.ipv4.nat "$BACKUP_DIR/"

echo "📁 Backup saved to: $BACKUP_DIR"

# 📝 Generate fresh dhcpcd config
echo "📝 Creating clean /etc/dhcpcd.conf..."
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

interface wlan0
    static ip_address=${static_ip}/24
    nohook wpa_supplicant
EOF

sudo systemctl restart dhcpcd

# 🌐 DNSMasq config for DHCP
echo "🌐 Configuring dnsmasq..."
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig 2>/dev/null || true
cat <<EOF | sudo tee /etc/dnsmasq.conf
interface=wlan0
dhcp-range=${dhcp_start},${dhcp_end},255.255.255.0,24h
EOF

# 📡 Hostapd config for Access Point
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

# Point hostapd to the config
sudo sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# 📶 Enable services
echo "📶 Enabling services..."
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq

# 🔁 Optional: NAT internet sharing
if [[ "$enable_nat" =~ ^[Yy]$ ]]; then
  echo "🌍 Setting up NAT for internet sharing..."
  echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
  sudo sysctl -w net.ipv4.ip_forward=1

  sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"

  # Create systemd service to restore iptables rules on boot
  echo "🔧 Creating systemd service for iptables restore..."
  cat <<EOF | sudo tee /etc/systemd/system/iptables-restore.service
[Unit]
Description=Restore iptables rules
After=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables.ipv4.nat
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl enable iptables-restore.service
fi

# 🌐 Create web server for hotspot configuration
echo "🌐 Setting up web configuration server..."
sudo mkdir -p /opt/hotspot-config
cat <<'EOF' | sudo tee /opt/hotspot-config/app.py
#!/usr/bin/env python3
import os
import subprocess
import json
from flask import Flask, render_template, request, jsonify, redirect, url_for

app = Flask(__name__)

def run_command(cmd):
    """Run shell command and return output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        return False, "", str(e)

def get_current_config():
    """Get current hotspot configuration"""
    config = {}
    
    # Get SSID from hostapd.conf
    try:
        with open('/etc/hostapd/hostapd.conf', 'r') as f:
            content = f.read()
            for line in content.split('\n'):
                if line.startswith('ssid='):
                    config['ssid'] = line.split('=', 1)[1]
                elif line.startswith('channel='):
                    config['channel'] = line.split('=', 1)[1]
    except:
        config['ssid'] = 'Unknown'
        config['channel'] = '7'
    
    # Get IP from dhcpcd.conf
    try:
        with open('/etc/dhcpcd.conf', 'r') as f:
            content = f.read()
            for line in content.split('\n'):
                if 'static ip_address=' in line:
                    config['ip'] = line.split('=')[1].split('/')[0].strip()
    except:
        config['ip'] = '192.168.4.1'
    
    # Get DHCP range from dnsmasq.conf
    try:
        with open('/etc/dnsmasq.conf', 'r') as f:
            content = f.read()
            for line in content.split('\n'):
                if line.startswith('dhcp-range='):
                    parts = line.split('=')[1].split(',')
                    config['dhcp_start'] = parts[0]
                    config['dhcp_end'] = parts[1]
    except:
        config['dhcp_start'] = '192.168.4.2'
        config['dhcp_end'] = '192.168.4.20'
    
    return config

@app.route('/')
def index():
    config = get_current_config()
    return render_template('index.html', config=config)

@app.route('/update', methods=['POST'])
def update_config():
    try:
        ssid = request.form.get('ssid', '').strip()
        password = request.form.get('password', '').strip()
        ip = request.form.get('ip', '').strip()
        dhcp_start = request.form.get('dhcp_start', '').strip()
        dhcp_end = request.form.get('dhcp_end', '').strip()
        channel = request.form.get('channel', '7').strip()
        
        if not ssid or not password or len(password) < 8:
            return jsonify({'success': False, 'error': 'SSID and password (min 8 chars) are required'})
        
        # Update hostapd.conf
        hostapd_config = f"""interface=wlan0
driver=nl80211
ssid={ssid}
hw_mode=g
channel={channel}
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase={password}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
"""
        with open('/tmp/hostapd.conf', 'w') as f:
            f.write(hostapd_config)
        run_command('sudo cp /tmp/hostapd.conf /etc/hostapd/hostapd.conf')
        
        # Update dhcpcd.conf
        dhcpcd_config = f"""hostname
clientid
persistent
option rapid_commit
option domain_name_servers, domain_name, domain_search, host_name
option classless_static_routes
option interface_mtu
require dhcp_server_identifier
slaac private

interface wlan0
    static ip_address={ip}/24
    nohook wpa_supplicant
"""
        with open('/tmp/dhcpcd.conf', 'w') as f:
            f.write(dhcpcd_config)
        run_command('sudo cp /tmp/dhcpcd.conf /etc/dhcpcd.conf')
        
        # Update dnsmasq.conf
        dnsmasq_config = f"""interface=wlan0
dhcp-range={dhcp_start},{dhcp_end},255.255.255.0,24h
"""
        with open('/tmp/dnsmasq.conf', 'w') as f:
            f.write(dnsmasq_config)
        run_command('sudo cp /tmp/dnsmasq.conf /etc/dnsmasq.conf')
        
        return jsonify({'success': True, 'message': 'Configuration updated! Restart required for changes to take effect.'})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/restart')
def restart_services():
    try:
        run_command('sudo systemctl restart hostapd')
        run_command('sudo systemctl restart dnsmasq')
        run_command('sudo systemctl restart dhcpcd')
        return jsonify({'success': True, 'message': 'Services restarted successfully!'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/reboot')
def reboot_system():
    try:
        subprocess.Popen(['sudo', 'reboot'])
        return jsonify({'success': True, 'message': 'System is rebooting...'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80, debug=False)
EOF

# Create HTML template
sudo mkdir -p /opt/hotspot-config/templates
cat <<'EOF' | sudo tee /opt/hotspot-config/templates/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hotspot Configuration</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
            margin-bottom: 30px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
            color: #555;
        }
        input[type="text"], input[type="password"], select {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 16px;
            box-sizing: border-box;
        }
        button {
            background-color: #007bff;
            color: white;
            padding: 12px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
            margin: 5px;
        }
        button:hover {
            background-color: #0056b3;
        }
        .danger {
            background-color: #dc3545;
        }
        .danger:hover {
            background-color: #c82333;
        }
        .success {
            background-color: #28a745;
        }
        .success:hover {
            background-color: #218838;
        }
        .message {
            padding: 10px;
            margin: 10px 0;
            border-radius: 5px;
            display: none;
        }
        .message.success {
            background-color: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .message.error {
            background-color: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        .current-config {
            background-color: #e9ecef;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .buttons {
            text-align: center;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔧 Hotspot Configuration</h1>
        
        <div class="current-config">
            <h3>Current Configuration</h3>
            <p><strong>SSID:</strong> {{ config.ssid }}</p>
            <p><strong>IP Address:</strong> {{ config.ip }}</p>
            <p><strong>DHCP Range:</strong> {{ config.dhcp_start }} - {{ config.dhcp_end }}</p>
            <p><strong>Channel:</strong> {{ config.channel }}</p>
        </div>
        
        <div id="message" class="message"></div>
        
        <form id="configForm">
            <div class="form-group">
                <label for="ssid">Wi-Fi Network Name (SSID):</label>
                <input type="text" id="ssid" name="ssid" value="{{ config.ssid }}" required>
            </div>
            
            <div class="form-group">
                <label for="password">Wi-Fi Password (min 8 characters):</label>
                <input type="password" id="password" name="password" placeholder="Enter new password" required>
            </div>
            
            <div class="form-group">
                <label for="ip">Static IP Address:</label>
                <input type="text" id="ip" name="ip" value="{{ config.ip }}" required>
            </div>
            
            <div class="form-group">
                <label for="dhcp_start">DHCP Range Start:</label>
                <input type="text" id="dhcp_start" name="dhcp_start" value="{{ config.dhcp_start }}" required>
            </div>
            
            <div class="form-group">
                <label for="dhcp_end">DHCP Range End:</label>
                <input type="text" id="dhcp_end" name="dhcp_end" value="{{ config.dhcp_end }}" required>
            </div>
            
            <div class="form-group">
                <label for="channel">Wi-Fi Channel:</label>
                <select id="channel" name="channel">
                    <option value="1" {% if config.channel == '1' %}selected{% endif %}>1</option>
                    <option value="6" {% if config.channel == '6' %}selected{% endif %}>6</option>
                    <option value="7" {% if config.channel == '7' %}selected{% endif %}>7</option>
                    <option value="11" {% if config.channel == '11' %}selected{% endif %}>11</option>
                </select>
            </div>
            
            <div class="buttons">
                <button type="submit">💾 Update Configuration</button>
                <button type="button" onclick="restartServices()" class="success">🔄 Restart Services</button>
                <button type="button" onclick="rebootSystem()" class="danger">🔄 Reboot System</button>
            </div>
        </form>
    </div>
    
    <script>
        function showMessage(text, type) {
            const message = document.getElementById('message');
            message.textContent = text;
            message.className = 'message ' + type;
            message.style.display = 'block';
            setTimeout(() => {
                message.style.display = 'none';
            }, 5000);
        }
        
        document.getElementById('configForm').addEventListener('submit', function(e) {
            e.preventDefault();
            
            const formData = new FormData(this);
            
            fetch('/update', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showMessage(data.message, 'success');
                    setTimeout(() => location.reload(), 2000);
                } else {
                    showMessage(data.error, 'error');
                }
            })
            .catch(error => {
                showMessage('Error: ' + error, 'error');
            });
        });
        
        function restartServices() {
            if (confirm('Restart hotspot services? This may temporarily disconnect clients.')) {
                fetch('/restart')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        showMessage(data.message, 'success');
                    } else {
                        showMessage(data.error, 'error');
                    }
                });
            }
        }
        
        function rebootSystem() {
            if (confirm('Reboot the entire system? This will disconnect all clients.')) {
                fetch('/reboot')
                .then(response => response.json())
                .then(data => {
                    showMessage('System is rebooting...', 'success');
                });
            }
        }
    </script>
</body>
</html>
EOF

# Create systemd service for the web server
cat <<EOF | sudo tee /etc/systemd/system/hotspot-config.service
[Unit]
Description=Hotspot Configuration Web Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/hotspot-config
ExecStart=/usr/bin/python3 /opt/hotspot-config/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the web server
sudo systemctl enable hotspot-config.service

echo "✅ Hotspot setup complete!"
echo ""
echo "🌐 Web Configuration Interface:"
echo "   Access: http://${static_ip} or http://192.168.4.1"
echo "   Available after reboot to modify hotspot settings"
echo ""
echo "📡 Hotspot Details:"
echo "   SSID: ${ssid}"
echo "   IP Address: ${static_ip}"
echo "   DHCP Range: ${dhcp_start} - ${dhcp_end}"
echo ""
echo "🔄 Rebooting in 5 seconds..."
sleep 5
sudo reboot
