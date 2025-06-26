#!/bin/bash

# 🔧 Complete Hotspot Setup - Creates missing components and starts services
# This script completes the hotspot setup by creating the web interface and starting services

echo "🌐 Creating Flask web application..."

# Create Flask web application
sudo tee /opt/hotspot-config/app.py << 'EOF'
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

echo "📄 Creating HTML template..."

# Create templates directory and HTML template
sudo mkdir -p /opt/hotspot-config/templates
sudo tee /opt/hotspot-config/templates/index.html << 'EOF'
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

echo "⚙️  Creating systemd service..."

# Create systemd service for the web server
sudo tee /etc/systemd/system/hotspot-config.service << 'EOF'
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

echo "🔧 Making Flask app executable..."
sudo chmod +x /opt/hotspot-config/app.py

echo "📶 Enabling and starting services..."

# Reload systemd and enable services
sudo systemctl daemon-reload
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl enable hotspot-config.service

# Restart dhcpcd to apply static IP
sudo systemctl restart dhcpcd

echo "⏸️  Stopping services before restart..."
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo systemctl stop hotspot-config 2>/dev/null || true

echo "🚀 Starting services..."
sleep 2

# Start services in order
sudo systemctl start dnsmasq
sleep 1
sudo systemctl start hostapd
sleep 1
sudo systemctl start hotspot-config.service

echo ""
echo "📊 Service Status Check:"
echo "========================"

echo "🌐 DNSMASQ Status:"
sudo systemctl is-active dnsmasq && echo "✅ Active" || echo "❌ Failed"

echo "📡 HOSTAPD Status:"
sudo systemctl is-active hostapd && echo "✅ Active" || echo "❌ Failed"

echo "🖥️  WEB SERVER Status:"
sudo systemctl is-active hotspot-config && echo "✅ Active" || echo "❌ Failed"

echo ""
echo "📄 Configuration Files Check:"
echo "============================="

if [ -f /etc/hostapd/hostapd.conf ]; then
    echo "✅ /etc/hostapd/hostapd.conf exists"
    ssid=$(grep "^ssid=" /etc/hostapd/hostapd.conf 2>/dev/null | cut -d'=' -f2 || echo "Unknown")
    echo "   📶 SSID: $ssid"
else
    echo "❌ /etc/hostapd/hostapd.conf missing"
fi

if [ -f /etc/dnsmasq.conf ]; then
    echo "✅ /etc/dnsmasq.conf exists"
    dhcp=$(grep "^dhcp-range=" /etc/dnsmasq.conf 2>/dev/null | cut -d'=' -f2 || echo "Unknown")
    echo "   📦 DHCP Range: $dhcp"
else
    echo "❌ /etc/dnsmasq.conf missing"
fi

if [ -f /etc/dhcpcd.conf ]; then
    echo "✅ /etc/dhcpcd.conf exists"
    ip=$(grep "static ip_address=" /etc/dhcpcd.conf 2>/dev/null | cut -d'=' -f2 | cut -d'/' -f1 | xargs || echo "Unknown")
    echo "   🌐 Static IP: $ip"
else
    echo "❌ /etc/dhcpcd.conf missing"
fi

echo ""
echo "🎉 HOTSPOT SETUP COMPLETE!"
echo "=========================="
echo "📡 SSID: MyHotspot"
echo "🔑 Password: mypass123"
echo "🌐 Pi IP Address: 192.168.4.1"
echo "📦 DHCP Range: 192.168.4.2 - 192.168.4.20"
echo "🖥️  Web Interface: http://192.168.4.1"
echo ""
echo "🔍 To verify the hotspot is working:"
echo "   1. Look for 'MyHotspot' in available Wi-Fi networks"
echo "   2. Connect using password 'mypass123'"
echo "   3. Open browser and go to http://192.168.4.1"
echo ""
echo "📋 If hotspot not visible, try:"
echo "   sudo systemctl restart hostapd"
echo "   sudo systemctl restart dnsmasq"

# Final check - show any errors
echo ""
echo "🔧 Troubleshooting Info:"
echo "======================="
if ! sudo systemctl is-active hostapd >/dev/null; then
    echo "❌ HOSTAPD Issues:"
    sudo systemctl status hostapd --no-pager -l | tail -5
fi

if ! sudo systemctl is-active dnsmasq >/dev/null; then
    echo "❌ DNSMASQ Issues:"
    sudo systemctl status dnsmasq --no-pager -l | tail -5
fi

if ! sudo systemctl is-active hotspot-config >/dev/null; then
    echo "❌ WEB SERVER Issues:"
    sudo systemctl status hotspot-config --no-pager -l | tail -5
fi
