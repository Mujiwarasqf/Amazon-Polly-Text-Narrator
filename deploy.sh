#!/usr/bin/env bash
set -euo pipefail

pushd terraform/lambda >/dev/null
bash build.sh
bash build-signer.sh
popd >/dev/null

pushd terraform >/dev/null
terraform init
terraform apply -auto-approve
popd >/dev/null

echo "Done. Set window.API_BASE in ui/env.js to api_base_url and upload ui/ to the UI bucket."
