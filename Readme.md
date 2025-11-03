# 🎙️ AWS Polly Text Narrator

A fully serverless application that converts uploaded text files into spoken MP3 audio using **AWS Polly**, **Lambda**, **S3**, **API Gateway**, and **CloudFront**, all provisioned through **Terraform**.

This project demonstrates a modern **event-driven architecture** using AWS managed services, showcasing automation, scalability, and cost-efficiency — perfect for portfolios, DevOps practice, or serverless product prototypes.

---

## 🚀 Project Overview

The **AWS Polly Text Narrator** allows users to upload a text file through a browser UI.  
Once uploaded, an automated backend workflow processes the file and generates an audio narration (MP3), which users can then stream or download via a CloudFront-served interface.

The project highlights:
- **Infrastructure as Code (IaC)** with Terraform
- **Event-driven compute** using AWS Lambda
- **Cloud-native text-to-speech pipeline** via AWS Polly
- **Static front-end hosting** through S3 + CloudFront
- **Secure upload/download workflow** using presigned URLs

---

## 🧩 Architecture Summary

### 🔹 1. S3 Buckets
- **Data Bucket (`sqf-bucket`)**  
  - Stores `input/*.txt` text files uploaded by users.  
  - Stores generated `output/*.mp3` files.  
  - Triggers the **Polly Lambda** when new `.txt` files appear.

- **UI Bucket (`sqf-ui-bucket`)**  
  - Hosts the static web interface (HTML, CSS, JS).  
  - Secured behind a CloudFront distribution using **Origin Access Control (OAC)** for private S3 access.

---

### 🔹 2. AWS Lambda Functions
- **Polly Worker (`polly-text-narrator-lambda`)**  
  - Triggered automatically by S3 events on `input/*.txt`.  
  - Reads text from S3, invokes **AWS Polly** to synthesize speech, and saves the resulting MP3 back to S3 (`output/*.mp3`).  
  - Environment variables define input/output prefixes, voice ID, and format.

- **Signer Function (`polly-text-narrator-signer`)**  
  - Provides **presigned PUT and GET URLs** to securely upload and fetch files without exposing AWS credentials.  
  - Integrated with an **API Gateway HTTP API** that exposes two endpoints:
    - `GET /sign-put` → presigned URL for uploading text  
    - `GET /sign-get` → presigned URL for retrieving generated MP3s  
  - Handles CORS automatically for the front-end UI.

---

### 🔹 3. AWS Polly (TTS Service)
- Converts text content into realistic speech using neural voices (e.g., *Joanna*).
- Configurable via Lambda environment variables or per-file metadata.

---

### 🔹 4. API Gateway
- Routes public HTTP requests from the UI to the **Signer Lambda**.  
- Provides a minimal REST interface for the front-end to obtain temporary upload/download URLs.  
- Uses the **AWS_PROXY integration type** for efficient Lambda invocation.

---

### 🔹 5. CloudFront + S3 (Frontend UI)
- The static front-end is hosted in S3 and served globally via CloudFront.  
- CloudFront handles HTTPS and caching.  
- Users interact with this UI to paste text, upload it, and play the generated audio.

---

## 🖥️ Workflow

1. **User Interface**  
   User opens the CloudFront URL and inputs text → clicks **Upload**.

2. **Presigned PUT URL**  
   UI requests a temporary signed URL from the API Gateway (`/sign-put`).

3. **Text Upload**  
   Browser uploads the `.txt` file directly to `sqf-bucket/input/` using the presigned URL.

4. **S3 Event Trigger**  
   The upload triggers the **Polly Lambda** function via S3 event notifications.

5. **Text-to-Speech Conversion**  
   Lambda reads the text, sends it to AWS Polly, receives an MP3 stream, and writes it to `sqf-bucket/output/`.

6. **Playback**  
   The user clicks **Refresh Play Link**, which fetches a presigned GET URL from `/sign-get` and plays the audio directly in the browser.

---

## 🛠️ Resources Summary

| AWS Service | Resource | Purpose |
|--------------|-----------|----------|
| **S3** | `sqf-bucket` | Stores text inputs & generated MP3 outputs |
| **S3** | `sqf-ui-bucket` | Hosts static front-end files |
| **Lambda** | `polly-text-narrator-lambda` | Executes text-to-speech conversions |
| **Lambda** | `polly-text-narrator-signer` | Issues presigned upload/download URLs |
| **Polly** | — | Converts text → speech (MP3) |
| **API Gateway (HTTP)** | `polly-text-narrator-httpapi` | Public endpoint for presigned URLs |
| **CloudFront** | `ui_cdn` | Serves UI via HTTPS from the UI S3 bucket |
| **IAM Roles & Policies** | — | Grants least-privilege access between components |
| **CloudWatch** | — | Monitors Lambda logs and errors |

---

## 🧠 How It All Comes Together

This project is an **end-to-end serverless pipeline** built with Terraform:

- **Frontend (UI + API)**  
  Users interact through CloudFront. The frontend calls API Gateway to get presigned URLs.
  
- **Storage (S3)**  
  Text inputs and generated audio files are persisted in versioned, secure S3 buckets.

- **Compute (Lambda + Polly)**  
  Text uploads automatically trigger computation in a scalable, pay-per-use model.

- **Infrastructure (Terraform)**  
  The entire stack — from IAM roles to CloudFront distributions — is declaratively managed in code for repeatability and automation.

Result: A **fully automated text-to-speech web service** with zero servers, near-zero maintenance, and scalable performance.

---

## ⚙️ Deployment Summary

```bash
cd terraform/lambda
bash build.sh && bash build-signer.sh

cd ..
terraform init
terraform apply -auto-approve
