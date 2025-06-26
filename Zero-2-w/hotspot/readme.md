# Pi Hotspot Setup

This script turns your Raspberry Pi Zero 2 W (or other Pi with Wi-Fi) into a mobile Wi-Fi hotspot.  
You can use it to:

- Broadcast a custom Wi-Fi network (SSID + password)
- Automatically assign IP addresses via DHCP
- Optionally share internet from Ethernet (`eth0`) to connected Wi-Fi clients

---

## 🔧 Features

- Interactive setup (you choose SSID, password, IP range, etc.)
- Configures `hostapd`, `dnsmasq`, and `dhcpcd`
- Supports NAT (internet sharing from Ethernet)
- Automatically enables services on boot

---

## 📦 Requirements

- Raspberry Pi OS (Lite or Full)
- Raspberry Pi with built-in Wi-Fi (e.g., Pi Zero 2 W, Pi 3, 4, etc.)
- Internet access to install packages

---

## 🚀 Setup

1. Clone the repo:

```bash
git clone https://github.com/nobleskye/PI-Scripts.git
cd PI-Scripts
cd Zero-2-w/hotspot
```
    Follow the prompts to configure:

    Wi-Fi name (SSID)

    Wi-Fi password

    Static IP (for Pi’s wlan0)

    DHCP range

    Optionally enable internet sharing

    The Pi will reboot when setup is complete.

🌐 Access Point Details (default)

If you accept defaults, your Pi will:

    Host Wi-Fi on 192.168.4.1

    Serve DHCP in 192.168.4.2 – 192.168.4.20


    ---

    ## 🌐 Access Point Details (default)

    If you accept defaults, your Pi will:

    - Host Wi-Fi on `192.168.4.1`
    - Serve DHCP in `192.168.4.2 – 192.168.4.20`
    - Use `hostapd` and `dnsmasq` to manage connections
    - (Optionally) share internet from `eth0`

    ---

    ## 🧠 Notes

    - To change the hotspot settings later, rerun the script or manually edit:

        - `/etc/dhcpcd.conf`
        - `/etc/dnsmasq.conf`
        - `/etc/hostapd/hostapd.conf`

    - To stop the hotspot:

        ```bash
        sudo systemctl stop hostapd dnsmasq
        ```

    ---

    ## ✅ Tested on:

    - Raspberry Pi Zero 2 W
    - Raspberry Pi OS Lite (32-bit)


    (Optionally) share internet from eth0

🧠 Notes

    To change the hotspot settings later, rerun the script or manually edit:

        /etc/dhcpcd.conf

        /etc/dnsmasq.conf

        /etc/hostapd/hostapd.conf

    To stop the hotspot:

sudo systemctl stop hostapd dnsmasq

✅ Tested on:

* Raspberry Pi Zero 2 W
* Raspberry Pi OS Lite (32-bit)