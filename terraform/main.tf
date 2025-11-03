terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" { region = var.aws_region }

locals {
  input_prefix  = "input/"
  output_prefix = "output/"
  lambda_name   = "${var.project_name}-lambda"
  bucket_arn    = "arn:aws:s3:::${var.bucket_name}"
}

# ---------------- Data bucket (text in, mp3 out) ----------------------------
resource "aws_s3_bucket" "textio" { bucket = var.bucket_name }

resource "aws_s3_bucket_public_access_block" "textio_pab" {
  bucket                  = aws_s3_bucket.textio.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "textio_versioning" {
  bucket = aws_s3_bucket.textio.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_object" "input_prefix" {
  bucket = aws_s3_bucket.textio.id
  key    = local.input_prefix
}

resource "aws_s3_object" "output_prefix" {
  bucket = aws_s3_bucket.textio.id
  key    = local.output_prefix
}

# Optional: permissive CORS for demo (tighten in prod)
resource "aws_s3_bucket_cors_configuration" "data_cors" {
  bucket = aws_s3_bucket.textio.id
  cors_rule {
    allowed_methods = ["GET", "PUT"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 300
  }
}

# ---------------- Lambda Exec Role & Policy ---------------------------------
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project_name}-exec"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

data "aws_iam_policy_document" "lambda_inline" {
  statement {
    sid       = "PollySynthesize"
    actions   = ["polly:SynthesizeSpeech", "polly:ListVoices"]
    resources = ["*"]
  }

  statement {
    sid = "S3RWDataBucket"
    actions = ["s3:GetObject","s3:PutObject"]
    resources = [
      "${local.bucket_arn}/${local.input_prefix}*",
      "${local.bucket_arn}/${local.output_prefix}*"
    ]
  }

  statement {
    sid = "Logs"
    actions = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_policy" {
  name   = "${var.project_name}-policy"
  policy = data.aws_iam_policy_document.lambda_inline.json
}

resource "aws_iam_role_policy_attachment" "attach_lambda" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# ---------------- Polly Lambda ----------------------------------------------
locals { lambda_zip_path = "${path.module}/lambda/lambda.zip" }

resource "aws_lambda_function" "polly_tts" {
  function_name    = local.lambda_name
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  filename         = local.lambda_zip_path
  source_code_hash = filebase64sha256(local.lambda_zip_path)
  timeout          = 30
  environment {
    variables = {
      OUTPUT_PREFIX = local.output_prefix
      INPUT_PREFIX  = local.input_prefix
      BUCKET_NAME   = aws_s3_bucket.textio.bucket
      VOICE_ID      = "Joanna"
      OUTPUT_FORMAT = "mp3"
    }
  }
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.polly_tts.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.textio.arn
}

resource "aws_s3_bucket_notification" "notify" {
  bucket = aws_s3_bucket.textio.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.polly_tts.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".txt"
    filter_prefix       = local.input_prefix
  }
  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# ---------------- Signer Lambda + HTTP API ----------------------------------
resource "aws_iam_role" "signer_exec" {
  name               = "${var.project_name}-signer-exec"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

data "aws_iam_policy_document" "signer_inline" {
  statement {
    sid     = "AllowS3ForPresign"
    actions = ["s3:PutObject","s3:GetObject","s3:ListBucket"]
    resources = [
      "${local.bucket_arn}",
      "${local.bucket_arn}/${local.input_prefix}*",
      "${local.bucket_arn}/${local.output_prefix}*"
    ]
  }
  statement {
    sid = "Logs"
    actions = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "signer_policy" {
  name   = "${var.project_name}-signer-policy"
  policy = data.aws_iam_policy_document.signer_inline.json
}

resource "aws_iam_role_policy_attachment" "attach_signer" {
  role       = aws_iam_role.signer_exec.name
  policy_arn = aws_iam_policy.signer_policy.arn
}

locals { signer_zip_path = "${path.module}/lambda/signer.zip" }

resource "aws_lambda_function" "signer" {
  function_name    = "${var.project_name}-signer"
  role             = aws_iam_role.signer_exec.arn
  runtime          = "python3.12"
  handler          = "signer.lambda_handler"
  filename         = local.signer_zip_path
  source_code_hash = filebase64sha256(local.signer_zip_path)
  timeout          = 10
  environment {
    variables = {
      BUCKET_NAME   = aws_s3_bucket.textio.bucket
      OUTPUT_PREFIX = local.output_prefix
    }
  }
}

resource "aws_apigatewayv2_api" "httpapi" {
  name          = "${var.project_name}-httpapi"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "signer_int" {
  api_id                 = aws_apigatewayv2_api.httpapi.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.signer.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "sign_put" {
  api_id    = aws_apigatewayv2_api.httpapi.id
  route_key = "GET /sign-put"
  target    = "integrations/${aws_apigatewayv2_integration.signer_int.id}"
}

resource "aws_apigatewayv2_route" "sign_get" {
  api_id    = aws_apigatewayv2_api.httpapi.id
  route_key = "GET /sign-get"
  target    = "integrations/${aws_apigatewayv2_integration.signer_int.id}"
}

resource "aws_apigatewayv2_route" "sign_put_options" {
  api_id    = aws_apigatewayv2_api.httpapi.id
  route_key = "OPTIONS /sign-put"
  target    = "integrations/${aws_apigatewayv2_integration.signer_int.id}"
}

resource "aws_apigatewayv2_route" "sign_get_options" {
  api_id    = aws_apigatewayv2_api.httpapi.id
  route_key = "OPTIONS /sign-get"
  target    = "integrations/${aws_apigatewayv2_integration.signer_int.id}"
}

resource "aws_lambda_permission" "api_invoke_signer" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.signer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.httpapi.execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.httpapi.id
  name        = "$default"
  auto_deploy = true
}

# ---------------- UI bucket + CloudFront (OAC) -------------------------------
resource "aws_s3_bucket" "ui" { bucket = var.ui_bucket_name }

resource "aws_s3_bucket_public_access_block" "ui_pab" {
  bucket                  = aws_s3_bucket.ui.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "ui_versioning" {
  bucket = aws_s3_bucket.ui.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project_name}-ui-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "ui_cdn" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.ui.bucket_regional_domain_name
    origin_id                = "ui-s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "ui-s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03"
  }

  price_class = "PriceClass_100"
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

data "aws_iam_policy_document" "ui_bucket_policy" {
  statement {
    sid = "AllowCloudFrontOACRead"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.ui.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.ui_cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "ui_policy" {
  bucket = aws_s3_bucket.ui.id
  policy = data.aws_iam_policy_document.ui_bucket_policy.json
}

