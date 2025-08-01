#!/bin/bash
set -e

echo "=== Updating the system ==="
sudo apt update && sudo apt upgrade -y

echo "=== Installing build tools & dependencies ==="
sudo apt install -y git build-essential cmake libsdl2-dev libsdl2-mixer-dev libncurses-dev libpoco-dev libpng++-dev libhpdf-dev libwebp-dev unclutter


if [ -d "$HOME/craftos2" ]; then
  echo "=== craftos2 folder exists, pulling the latest changes ==="
  cd "$HOME/craftos2"
  git pull
else
  echo "=== Cloning craftos2 repository ==="
  git clone https://github.com/MCJack123/craftos2.git "$HOME/craftos2"
  cd "$HOME/craftos2"
fi

echo "=== Initializing submodules ==="
git submodule update --init --recursive

echo "=== Building craftos2 (CraftOS‑PC 2) ==="
cd craftos2
make

echo "=== Setting up launcher script ==="
cat <<EOF > "$HOME/launch-craftos.sh"
#!/bin/bash
unclutter &
cd "$HOME/craftos2/craftos2"
./craftos
EOF
chmod +x "$HOME/launch-craftos.sh"

echo "=== Adding autostart entry ==="
mkdir -p "$HOME/.config/autostart"
cat <<EOF > "$HOME/.config/autostart/craftos.desktop"
[Desktop Entry]
Type=Application
Exec=$HOME/launch-craftos.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=CraftOS‑PC 2
EOF

echo "=== Setup finished! CraftOS‑PC 2 will auto-start on desktop login ==="
