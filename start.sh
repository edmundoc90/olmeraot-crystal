#!/bin/bash
set -e

BIN_PATH=${1:-"crystalserver"}

mkdir -p logs

echo "[Info] Starting CrystalServer directly: $BIN_PATH"

ulimit -c unlimited

exec "$BIN_PATH"
