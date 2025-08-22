#!/usr/bin/env bash
set -euo pipefail

# Config
REPO_URL="https://github.com/trailofbits/algo.git"
PINNED_COMMIT="75cfeab24a077b141f3c91341fc1546004c48d15"
CHECKOUT_DIR="${CHECKOUT_DIR:-algo-${PINNED_COMMIT:0:7}}"

export DEBIAN_FRONTEND=noninteractive

echo "[1/8] Fetch pinned repo @ $PINNED_COMMIT → $CHECKOUT_DIR"
if [[ -d "$CHECKOUT_DIR/.git" ]]; then
  echo "    Repo dir exists; reusing."
else
  mkdir -p "$CHECKOUT_DIR"
  (
    cd "$CHECKOUT_DIR"
    git init -q
    git remote add origin "$REPO_URL" 2>/dev/null || true
    git fetch -q --depth=1 origin "$PINNED_COMMIT"
    git checkout -q FETCH_HEAD
  )
fi

echo "[2/8] apt update"
sudo apt-get update -y

echo "[3/8] Install prerequisites (git, virtualenv, zip)"
sudo apt-get install -y --no-install-recommends git python3-virtualenv zip

echo "[4/8] Create & activate venv"
cd "$CHECKOUT_DIR"
python3 -m virtualenv --python="$(command -v python3)" .env
# shellcheck disable=SC1091
source .env/bin/activate

echo "[5/8] Ensure pip/setuptools/wheel present (fixes pkg_resources)"
python3 -m pip install -U pip setuptools wheel virtualenv
python3 - <<'PY'
import pkg_resources, sys
print("[check] pkg_resources OK ->", pkg_resources.__version__)
PY

echo "[6/8] Install project requirements"
python3 -m pip install -r requirements.txt

echo "[7/8] Run ./algo"
./algo || {
  echo "Algo run failed; attempting one-time setuptools repair and retry…" >&2
  python3 -m pip install -U setuptools wheel
  ./algo
}

echo "[8/8] Zip the 'config' folder into config/vpn.zip"
if [[ ! -d "config" ]]; then
  echo "    'config' directory not found. Creating it so vpn.zip exists."
  mkdir -p config
fi
(
  cd config
  # zip contents into vpn.zip; exclude the archive itself
  zip -r vpn.zip . -x vpn.zip
)
echo "Done: $(realpath config/vpn.zip)"
