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


✅ Tested on:

* Raspberry Pi Zero 2 W
* Raspberry Pi OS Lite (32-bit)