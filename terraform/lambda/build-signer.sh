#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
rm -f signer.zip
powershell.exe -Command "Compress-Archive -Path signer.py -DestinationPath signer.zip -Force"
echo "Built signer.zip"
