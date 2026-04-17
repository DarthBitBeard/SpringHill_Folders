#!/bin/bash
# --- Spring Hill Folders Deployment (Team: 1068033) ---
TEAM_ID="1068033"

echo "--- Spring Hill Folders: Linux Automated Deployment ---"

# 1. Install Dependencies & Download
if [ -f /usr/bin/apt ]; then
    echo "[1/4] Updating system and downloading v8.5.5..."
    sudo apt update && sudo apt install -y wget
    wget https://download.foldingathome.org/releases/public/release/fah-client/debian-stable-64bit/v8.5/fah-client_8.5.5_amd64.deb -O /tmp/fah-client.deb
    
    # 2. Silent Install via dpkg
    echo "[2/4] Installing package..."
    sudo DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/fah-client.deb
else
    echo "This script currently supports Debian/Ubuntu based systems. Please install manually."
    exit 1
fi

# 3. Configure for v8
echo "[3/4] Applying Team $TEAM_ID and Idle-Only configuration..."
sudo mkdir -p /etc/fah-client
sudo cat <<EOF > /etc/fah-client/config.xml
<config>
  <user v='Anonymous'/>
  <team v='$TEAM_ID'/>
  <power v='full'/>
  <idle v='true'/>
</config>
EOF

# 4. Enable Service for Startup
echo "[4/4] Enabling startup service..."
sudo systemctl enable fah-client
sudo systemctl restart fah-client

echo "Setup complete! You can monitor progress at https://v8-5.foldingathome.org/"
