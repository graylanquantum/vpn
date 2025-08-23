#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────
# Settings
# ─────────────────────────────
BASE_DIR="$HOME"
ALGO_DIR="$BASE_DIR/algo"
ZIP_URL="https://github.com/trailofbits/algo/archive/75cfeab24a077b141f3c91341fc1546004c48d15.zip"
ZIP_FILE="$BASE_DIR/algo.zip"
EXPECTED_SHA="f47dd2636c0d0ba7ed642ce6c2f3251beeeff8771018bee9d303e6c0bbbe8e5"
export DEBIAN_FRONTEND=noninteractive

# ─────────────────────────────
# 1. Install system deps
# ─────────────────────────────
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends \
  unzip git python3-virtualenv zip curl python3-pip python3-dev build-essential expect

# ─────────────────────────────
# 2. Download Algo pinned zip
# ─────────────────────────────
echo "[*] Downloading Algo pinned zip"
wget -qO "$ZIP_FILE" "$ZIP_URL"

echo "[*] Verifying SHA256 checksum"
DOWNLOADED_SHA=$(sha256sum "$ZIP_FILE" | awk '{print $1}')
if [[ "$DOWNLOADED_SHA" != "$EXPECTED_SHA" ]]; then
  echo "ERROR: SHA256 checksum mismatch!"
  echo "Expected: $EXPECTED_SHA"
  echo "Got:      $DOWNLOADED_SHA"
  exit 1
fi
echo "[*] Checksum OK"

# ─────────────────────────────
# 3. Extract & rename
# ─────────────────────────────
rm -rf "$ALGO_DIR"
unzip -q "$ZIP_FILE" -d "$BASE_DIR"
mv "$BASE_DIR"/algo-* "$ALGO_DIR"

cd "$ALGO_DIR"

# ─────────────────────────────
# 4. Virtualenv setup
# ─────────────────────────────
echo "[*] Setting up Python venv"
python3 -m virtualenv --python="$(command -v python3)" .env
source .env/bin/activate
python3 -m pip install -U pip virtualenv
python3 -m pip install -U "setuptools<81" wheel
python3 -m pip install -r requirements.txt
export ANSIBLE_PYTHON_INTERPRETER="$PWD/.env/bin/python3"

# ─────────────────────────────
# 5. Automate Algo install via expect
# ─────────────────────────────
PUBLIC_IP=$(curl -s ifconfig.me || echo "127.0.0.1")
echo "[*] Detected public IP: $PUBLIC_IP"
echo "[*] Running Algo installer with automated inputs"

expect <<EOF
set timeout -1
spawn ./algo
expect "What provider would you like to use?"
send "12\r"
expect "Do you want to install an ad blocker?"
send "\r"
expect "Do you want to install the VPN on the local machine?"
send "\r"
expect "Do you want to allow your clients to use DNS over HTTPS?"
send "\r"
expect "Do you want to install a WireGuard VPN server?"
send "y\r"
expect "Do you want to retain the keys (keys will not be generated again)?"
send "\r"
expect "Enter the public IP address of your server"
send "$PUBLIC_IP\r"
expect eof
EOF

# ─────────────────────────────
# 6. Zip config
# ─────────────────────────────
echo "[*] Zipping config → config/vpn.zip"
mkdir -p config
( cd configs && zip -r ../config/vpn.zip . -x vpn.zip )
echo "Done: $(realpath config/vpn.zip || echo config/vpn.zip)"
