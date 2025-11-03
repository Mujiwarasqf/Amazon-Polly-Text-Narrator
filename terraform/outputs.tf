output "bucket_name"       { value = aws_s3_bucket.textio.bucket }
output "lambda_arn"        { value = aws_lambda_function.polly_tts.arn }
output "api_base_url"      { value = aws_apigatewayv2_api.httpapi.api_endpoint }
output "ui_cloudfront_url" { value = "https://${aws_cloudfront_distribution.ui_cdn.domain_name}" }
