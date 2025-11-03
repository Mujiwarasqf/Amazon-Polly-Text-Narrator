# =====================================================================
# Variable Definitions for Polly Text Narrator (AWS + Terraform)
# =====================================================================

variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "eu-west-2" # London
}

variable "project_name" {
  description = "Short name prefix for namespacing resources"
  type        = string
  default     = "polly-text-narrator"
}

variable "bucket_name" {
  description = "Main S3 bucket for text input and mp3 output"
  type        = string
  default     = "sqf-bucket"
}

variable "ui_bucket_name" {
  description = "S3 bucket for hosting the static UI via CloudFront"
  type        = string
  default     = "sqf-ui-bucket"
}
