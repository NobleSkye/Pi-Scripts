#!/bin/bash

set -e

echo "=== Installing dependencies ==="
sudo apt update
sudo apt install -y bluez bluez-tools dnsmasq python3-flask

echo "=== Configuring Bluetooth PAN ==="

# Start the NAP (Network Access Point) service on pan0
sudo bt-network -s nap pan0 &

# Wait a bit for interface to show up
sleep 3

# Bring up pan0 and assign static IP
sudo ip link set pan0 up
sudo ip addr add 192.168.50.1/24 dev pan0

echo "=== Configuring dnsmasq DHCP for pan0 ==="
sudo tee /etc/dnsmasq.d/pan0.conf > /dev/null <<EOF
interface=pan0
dhcp-range=192.168.50.10,192.168.50.20,255.255.255.0,24h
EOF

# Restart dnsmasq
sudo systemctl restart dnsmasq

echo "=== Enabling IP forwarding ==="
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

echo "=== Setting Bluetooth agent, pairable, discoverable, advertising ==="
bluetoothctl <<EOF
agent on
default-agent
pairable on
discoverable on
advertise on
EOF

echo "=== Starting Flask web panel ==="

# Create a minimal Flask app for Wi-Fi setup
mkdir -p ~/bt_panel
cat > ~/bt_panel/panel.py <<'PYEOF'
from flask import Flask, request, render_template_string
import os

app = Flask(__name__)

HTML = '''
<h2>Configure Wi-Fi</h2>
<form method="post">
  SSID: <input name="ssid"><br>
  Password: <input type="password" name="password"><br>
  <input type="submit" value="Connect">
</form>
'''

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        ssid = request.form['ssid']
        password = request.form['password']
        with open('/etc/wpa_supplicant/wpa_supplicant.conf', 'a') as f:
            f.write(f'\nnetwork={{\n    ssid="{ssid}"\n    psk="{password}"\n}}\n')
        os.system('wpa_cli -i wlan0 reconfigure')
        return f"<p>Added network {ssid}. Reconfiguring Wi-Fi...</p><a href='/'>Back</a>"
    return render_template_string(HTML)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PYEOF

# Install Flask requirements if needed
pip3 install flask

# Start Flask app in background
sudo python3 ~/bt_panel/panel.py &
                