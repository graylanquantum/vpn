#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────
# Settings
# ─────────────────────────────
BASE_DIR="$HOME"
ALGO_DIR="$BASE_DIR/algo"
ZIP_URL="https://github.com/trailofbits/algo/archive/75cfeab24a077b141f3c91341fc1546004c48d15.zip"
ZIP_FILE="$BASE_DIR/algo.zip"
EXPECTED_SHA="0f47dd2636c0d0ba7ed642ce6c2f3251beeeff8771018bee9d303e6c0bbbe8e5"

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a   # skip daemon restart dialog

# ─────────────────────────────
# 1. Install deps
# ─────────────────────────────
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends \
  unzip git python3-virtualenv zip curl python3-pip python3-dev build-essential expect dnsutils

# ─────────────────────────────
# 2. Download Algo pinned zip
# ─────────────────────────────
wget -qO "$ZIP_FILE" "$ZIP_URL"
DOWNLOADED_SHA=$(sha256sum "$ZIP_FILE" | awk '{print $1}')
if [[ "$DOWNLOADED_SHA" != "$EXPECTED_SHA" ]]; then
  echo "ERROR: SHA256 checksum mismatch!"
  exit 1
fi

rm -rf "$ALGO_DIR"
unzip -q "$ZIP_FILE" -d "$BASE_DIR"
mv "$BASE_DIR"/algo-* "$ALGO_DIR"
cd "$ALGO_DIR"

# ─────────────────────────────
# 3. Virtualenv setup
# ─────────────────────────────
python3 -m virtualenv --python="$(command -v python3)" .env
source .env/bin/activate
pip install -U pip virtualenv
pip install -U "setuptools<81" wheel
pip install -r requirements.txt
export ANSIBLE_PYTHON_INTERPRETER="$PWD/.env/bin/python3"

# ─────────────────────────────
# 4. Run Algo with hard-coded answers
# ─────────────────────────────
PUBLIC_IP=$(curl -4 -s ifconfig.me || dig +short myip.opendns.com @resolver1.opendns.com || echo "127.0.0.1")
echo "[*] Detected public IPv4: $PUBLIC_IP"

expect <<EOF
set timeout -1
spawn ./algo

sleep 2
send "12\r"
sleep 2
send "\r"
sleep 2
send "\r"
sleep 2
send "\r"
sleep 2
send "y\r"
sleep 2
send "\r"
sleep 2
send "\r"
sleep 2
send "\r"
sleep 2
send "\r"
sleep 2
send "$PUBLIC_IP\r"
sleep 2
send "\r"

expect eof
EOF

# ─────────────────────────────
# 5. Zip configs
# ─────────────────────────────
mkdir -p config
( cd configs && zip -r ../config/vpn.zip . -x vpn.zip )
echo "Done: $(realpath config/vpn.zip || echo config/vpn.zip)"
