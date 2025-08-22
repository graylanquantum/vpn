#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/trailofbits/algo.git"
PINNED_COMMIT="75cfeab24a077b141f3c91341fc1546004c48d15"
CHECKOUT_DIR="${CHECKOUT_DIR:-algo-${PINNED_COMMIT:0:7}}"
export DEBIAN_FRONTEND=noninteractive

echo "[1/7] Fetch pinned repo @ $PINNED_COMMIT → $CHECKOUT_DIR"
if [[ ! -d "$CHECKOUT_DIR/.git" ]]; then
  mkdir -p "$CHECKOUT_DIR"
  cd "$CHECKOUT_DIR"
  git init -q
  git remote add origin "$REPO_URL" 2>/dev/null || true
  git fetch -q --depth=1 origin "$PINNED_COMMIT"
  git checkout -q FETCH_HEAD
else
  cd "$CHECKOUT_DIR"
fi

echo "[2/7] apt update"
sudo apt-get update -y

echo "[3/7] Install prerequisites"
sudo apt-get install -y --no-install-recommends git python3-virtualenv zip

echo "[4/7] Create & activate venv"
python3 -m virtualenv --python="$(command -v python3)" .env
# shellcheck disable=SC1091
source .env/bin/activate

echo "[5/7] Upgrade tooling and keep pkg_resources available"
# Pin setuptools<81 to retain pkg_resources for tools that still need it.
python3 -m pip install -U "pip>=24" "setuptools<81" wheel virtualenv
python3 -m pip install -r requirements.txt

echo "[6/7] Run Algo"
./algo

echo "[7/7] Zip config → config/vpn.zip"
mkdir -p config
( cd config && zip -r vpn.zip . -x vpn.zip )
echo "Done: $(realpath config/vpn.zip || echo config/vpn.zip)"
