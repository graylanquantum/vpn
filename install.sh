#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────
# Settings
# ─────────────────────────────
BASE_DIR="${BASE_DIR:-$HOME/vpn}"
CHECKOUT_DIR="$BASE_DIR/algo-75cfeab"
REPO_URL="https://github.com/trailofbits/algo.git"
PINNED_COMMIT="75cfeab24a077b141f3c91341fc1546004c48d15"
export DEBIAN_FRONTEND=noninteractive

# ─────────────────────────────
# 1. Install system deps
# ─────────────────────────────
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends git python3-virtualenv zip curl

# ─────────────────────────────
# 2. Checkout Algo pinned
# ─────────────────────────────
mkdir -p "$BASE_DIR"
if [[ ! -d "$CHECKOUT_DIR/.git" ]]; then
  echo "[*] Fetching Algo pinned @ $PINNED_COMMIT"
  mkdir -p "$CHECKOUT_DIR"
  cd "$CHECKOUT_DIR"
  git init -q
  git remote add origin "$REPO_URL" 2>/dev/null || true
  git fetch -q --depth=1 origin "$PINNED_COMMIT"
  git checkout -q FETCH_HEAD
else
  cd "$CHECKOUT_DIR"
fi

# ─────────────────────────────
# 3. Virtualenv setup
# ─────────────────────────────
echo "[*] Setting up Python venv"
python3 -m virtualenv --python="$(command -v python3)" .env
# shellcheck disable=SC1091
source .env/bin/activate
python3 -m pip install -U pip virtualenv
python3 -m pip install -U "setuptools<81" wheel
python3 -m pip install -r requirements.txt
export ANSIBLE_PYTHON_INTERPRETER="$PWD/.env/bin/python3"

# ─────────────────────────────
# 4. Auto-generate config.cfg
# ─────────────────────────────
echo "[*] Writing config.cfg with defaults"
PUBLIC_IP=$(curl -s ifconfig.me || echo "127.0.0.1")
cat > config.cfg <<EOF
users:
  - vpnuser

dns:
  - 1.1.1.1
  - 8.8.8.8

wireguard_port: 51820
algo_server_ip: $PUBLIC_IP
endpoint: $PUBLIC_IP

EOF

# ─────────────────────────────
# 5. Run Algo non-interactive
# ─────────────────────────────
echo "[*] Running Algo unattended"
ANSIBLE_DISPLAY_SKIPPED_HOSTS=false \
ANSIBLE_RETRY_FILES_ENABLED=false \
./algo --non-interactive

# ─────────────────────────────
# 6. Zip config
# ─────────────────────────────
echo "[*] Zipping config → config/vpn.zip"
mkdir -p config
( cd config && zip -r vpn.zip . -x vpn.zip )
echo "Done: $(realpath config/vpn.zip || echo config/vpn.zip)"
