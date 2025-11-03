# Polly Text Narrator — Final Unified Bundle

**Date:** 2025-11-03

Defaults:
- `bucket_name` = `sqf-bucket`
- `ui_bucket_name` = `sqf-ui-bucket`
- `aws_region` = `eu-west-2`

## Deploy
```bash
cd terraform/lambda
bash build.sh
bash build-signer.sh

cd ..
terraform init
terraform apply -auto-approve
```

Outputs:
- `api_base_url` – paste into `ui/env.js`
- `ui_cloudfront_url` – open in the browser

## Update UI
Edit `ui/env.js`:
```js
window.API_BASE = "https://<your-api-id>.execute-api.eu-west-2.amazonaws.com";
```
Upload `ui/*` to the UI S3 bucket.

## Cleanup
```bash
terraform destroy
```
