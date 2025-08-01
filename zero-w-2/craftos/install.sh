#!/bin/bash
set -e

echo "=== Updating your system ==="
sudo apt update && sudo apt upgrade -y

echo "=== Installing build tools and dependencies ==="
sudo apt install -y git build-essential meson ninja-build libncurses-dev libsdl2-dev unclutter

if [ -d "$HOME/CraftOS-PC" ]; then
  echo "=== CraftOS-PC folder exists, pulling latest changes ==="
  cd "$HOME/CraftOS-PC"
  git pull
else
  echo "=== Cloning CraftOS-PC ==="
  git clone https://github.com/MCJack123/CraftOS-PC.git "$HOME/CraftOS-PC"
  cd "$HOME/CraftOS-PC"
fi

echo "=== Building CraftOS-PC ==="
rm -rf build
meson setup build
ninja -C build

echo "=== Creating launch script ==="
cat <<EOF > "$HOME/launch-craftos.sh"
#!/bin/bash
unclutter &
cd "$HOME/CraftOS-PC/build"
./craftos --fullscreen
EOF
chmod +x "$HOME/launch-craftos.sh"

echo "=== Creating autostart entry ==="
mkdir -p "$HOME/.config/autostart"
cat <<EOF > "$HOME/.config/autostart/craftos.desktop"
[Desktop Entry]
Type=Application
Exec=$HOME/launch-craftos.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=CraftOS-PC
EOF

echo "=== Setup complete! Reboot and CraftOS-PC will launch fullscreen on boot ==="
