#!/usr/bin/env bash
set -euo pipefail

# Config
REPO_URL="https://github.com/trailofbits/algo.git"
PINNED_COMMIT="75cfeab24a077b141f3c91341fc1546004c48d15"
CHECKOUT_DIR="${CHECKOUT_DIR:-algo-${PINNED_COMMIT:0:7}}"

export DEBIAN_FRONTEND=noninteractive

echo "[1/6] Fetching pinned repo @ $PINNED_COMMIT → $CHECKOUT_DIR"
if [[ -d "$CHECKOUT_DIR/.git" ]]; then
  echo "    Repo dir exists; reusing."
else
  mkdir -p "$CHECKOUT_DIR"
  git -C "$CHECKOUT_DIR" rev-parse --git-dir >/dev/null 2>&1 || true
  (
    cd "$CHECKOUT_DIR"
    git init -q
    git remote add origin "$REPO_URL" 2>/dev/null || true
    # Fetch exactly the pinned commit (works even if it's not on the default branch)
    git fetch -q --depth=1 origin "$PINNED_COMMIT"
    git checkout -q FETCH_HEAD
  )
fi

echo "[2/6] apt update"
sudo apt-get update -y

echo "[3/6] Installing prerequisites"
# Keep the requested package; add git in case it's missing.
sudo apt-get install -y --no-install-recommends git python3-virtualenv

echo "[4/6] Creating virtualenv"
cd "$CHECKOUT_DIR"
python3 -m virtualenv --python="$(command -v python3)" .env
# shellcheck disable=SC1091
source .env/bin/activate

echo "[5/6] Upgrading pip & virtualenv, installing requirements"
python3 -m pip install -U pip virtualenv
python3 -m pip install -r requirements.txt

echo "[6/6] Running ./algo"
./algo
