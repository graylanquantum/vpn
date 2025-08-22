#!/usr/bin/env bash
set -euo pipefail

# Paths
BASE_DIR="${BASE_DIR:-$HOME/vpn}"
CHECKOUT_DIR="$BASE_DIR/algo-75cfeab"
REPO_URL="https://github.com/trailofbits/algo.git"
PINNED_COMMIT="75cfeab24a077b141f3c91341fc1546004c48d15"

export DEBIAN_FRONTEND=noninteractive

# Ensure deps
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends git python3-virtualenv zip

# Fetch pinned commit into ~/vpn/algo-75cfeab (reuse if present)
mkdir -p "$BASE_DIR"
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

# >>> EXACT chain you requested, with one essential add (setuptools) before requirements <<<
python3 -m virtualenv --python="$(command -v python3)" .env &&
  source .env/bin/activate &&
  python3 -m pip install -U pip virtualenv &&
  python3 -m pip install -U "setuptools<81" wheel &&
  python3 -m pip install -r requirements.txt

# Make sure Ansible uses the venv’s Python (prevents pkg_resources errors)
export ANSIBLE_PYTHON_INTERPRETER="$PWD/.env/bin/python3"

# Run Algo
./algo

# Zip config into config/vpn.zip (create folder if missing)
mkdir -p config
( cd config && zip -r vpn.zip . -x vpn.zip )
echo "Created: $CHECKOUT_DIR/config/vpn.zip"
