from flask import Flask, render_template, request
import os

app = Flask(__name__)

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        ssid = request.form['ssid']
        password = request.form['password']
        # Save to wpa_supplicant.conf
        with open('/etc/wpa_supplicant/wpa_supplicant.conf', 'a') as f:
            f.write(f'\nnetwork={{\n    ssid="{ssid}"\n    psk="{password}"\n}}\n')
        os.system('wpa_cli -i wlan0 reconfigure')
        return "Wi-Fi settings updated! Reconnecting..."
    return '''
        <form method="post">
            SSID: <input name="ssid"><br>
            Password: <input name="password" type="password"><br>
            <input type="submit" value="Connect">
        </form>
    '''

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
