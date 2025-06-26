# 📡 Pi Hotspot Setup

Transform your Raspberry Pi Zero 2 W (or other Pi with Wi-Fi) into a mobile Wi-Fi hotspot!

**Perfect for:**
- Creating a portable Wi-Fi network anywhere
- Broadcasting a custom Wi-Fi network with your own SSID and password
- Automatically assigning IP addresses to connected devices via DHCP
- Optionally sharing internet from Ethernet (`eth0`) to connected Wi-Fi clients

---

## ✨ Features

- **Interactive setup** - Choose your SSID, password, IP range, and more
- **Complete configuration** - Automatically configures `hostapd`, `dnsmasq`, and `dhcpcd`
- **Internet sharing** - Support for NAT (share internet from Ethernet to Wi-Fi)
- **Auto-start** - Services automatically enable on boot
- **Easy management** - Simple commands to start, stop, and reconfigure

---

## 📋 Requirements

- **OS:** Raspberry Pi OS (Lite or Full)
- **Hardware:** Raspberry Pi with built-in Wi-Fi (Pi Zero 2 W, Pi 3, Pi 4, etc.)
- **Network:** Internet access during setup (to install packages)

---

## 🚀 Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/nobleskye/PI-Scripts.git
   cd PI-Scripts/Zero-2-w/hotspot
   ```

2. **Run the setup script:**
   ```bash
   sudo bash setup-hotspot.sh
   ```

3. **Follow the interactive prompts to configure:**
   - Wi-Fi name (SSID)
   - Wi-Fi password
   - Static IP address for Pi's `wlan0` interface
   - DHCP IP range for connected devices
   - Internet sharing options

4. **Reboot when prompted** - Your Pi will automatically start broadcasting the hotspot after reboot!

---

## 🌐 Default Network Configuration

If you accept the default settings, your Pi will create:

| Setting | Value |
|---------|-------|
| **Pi IP Address** | `192.168.4.1` |
| **DHCP Range** | `192.168.4.2` - `192.168.4.20` |
| **Services** | `hostapd` and `dnsmasq` |
| **Internet Sharing** | Optional via `eth0` |

---

## 🔧 Management Commands

### Stop the hotspot:
```bash
sudo systemctl stop hostapd dnsmasq
```

### Start the hotspot:
```bash
sudo systemctl start hostapd dnsmasq
```

### Check status:
```bash
sudo systemctl status hostapd dnsmasq
```

---

## ⚙️ Manual Configuration

To modify hotspot settings after setup, edit these configuration files:

- **DHCP settings:** `/etc/dhcpcd.conf`
- **DNS/DHCP server:** `/etc/dnsmasq.conf`  
- **Access point:** `/etc/hostapd/hostapd.conf`

Or simply rerun the setup script to reconfigure interactively.

---

## ✅ Tested Platforms

- **Raspberry Pi Zero 2 W** ✓
- **Raspberry Pi OS Lite (32-bit)** ✓
- **Raspberry Pi 3/4** (should work)

---

## 🆘 Troubleshooting

If you encounter issues:

1. **Check service status:**
   ```bash
   sudo systemctl status hostapd dnsmasq
   ```

2. **View logs:**
   ```bash
   sudo journalctl -u hostapd -f
   sudo journalctl -u dnsmasq -f
   ```

3. **Restart services:**
   ```bash
   sudo systemctl restart hostapd dnsmasq
   ```

---

*Made with ❤️ for the Raspberry Pi community*
