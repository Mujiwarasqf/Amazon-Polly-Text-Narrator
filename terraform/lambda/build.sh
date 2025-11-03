#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
rm -f lambda.zip
powershell.exe -Command "Compress-Archive -Path lambda_function.py -DestinationPath lambda.zip -Force"
echo "Built lambda.zip"
