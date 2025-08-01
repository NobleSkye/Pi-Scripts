#!/bin/bash
set -e

echo "=== Updating system ==="
sudo apt update && sudo apt upgrade -y

echo "=== Installing required build dependencies ==="
sudo apt install -y git build-essential meson ninja-build \
libsdl2-dev libsdl2-mixer-dev libhpdf-dev libpng++-dev libwebp-dev \
libpoco-dev libncurses-dev unclutter cmake

echo "=== Cloning CraftOS-PC 2 repo ==="
if [ -d "$HOME/craftos2" ]; then
  cd "$HOME/craftos2"
  git pull
else
  git clone --recursive https://github.com/MCJack123/craftos2.git "$HOME/craftos2"
  cd "$HOME/craftos2"
fi

echo "=== Initializing submodules ==="
git submodule update --init --recursive

echo "=== Building craftos2 with meson and ninja ==="
meson setup build --wipe || meson setup build
ninja -C build

echo "=== Copy your ComputerCraft ROM files ==="
echo "You must download the ComputerCraft ROM files separately and copy them to /usr/local/share/craftos/"
echo "Example:"
echo "  sudo mkdir -p /usr/local/share/craftos"
echo "  sudo cp -r path_to_your_CC_ROM/* /usr/local/share/craftos/"

echo "=== Creating launch script ==="
cat > "$HOME/launch-craftos.sh" <<EOF
#!/bin/bash
unclutter &
cd "$HOME/craftos2/build"
./craftos
EOF
chmod +x "$HOME/launch-craftos.sh"

echo "=== Creating autostart entry ==="
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/craftos.desktop" <<EOF
[Desktop Entry]
Type=Application
Exec=$HOME/launch-craftos.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=CraftOS-PC 2
EOF

echo "=== Setup complete! ==="
echo "Run with: $HOME/launch-craftos.sh"
echo "Don't forget to copy the ComputerCraft ROM files as described above!"
