import os, json, urllib.parse
import boto3

s3 = boto3.client('s3')
BUCKET = os.environ['BUCKET_NAME']
OUTPUT_PREFIX = os.environ.get('OUTPUT_PREFIX', 'output/')

def _resp(status, body, origin="*"):
    return {
        "statusCode": status,
        "headers": {
            "content-type": "application/json",
            "access-control-allow-origin": origin,
            "access-control-allow-headers": "*",
            "access-control-allow-methods": "GET,OPTIONS"
        },
        "body": json.dumps(body)
    }

def _presign_put(key, content_type="application/octet-stream"):
    return s3.generate_presigned_url(
        ClientMethod="put_object",
        Params={
            "Bucket": BUCKET, 
            "Key": key, 
            "ContentType": content_type,
            "Metadata": {"voice": "Joanna"}
        },
        ExpiresIn=900
    )

def _presign_get(key):
    return s3.generate_presigned_url(
        ClientMethod="get_object",
        Params={"Bucket": BUCKET, "Key": key},
        ExpiresIn=900
    )

def lambda_handler(event, context):
    route = (event.get("requestContext", {}).get("http", {}).get("path") or "").lower()
    method = (event.get("requestContext", {}).get("http", {}).get("method") or "").upper()
    params = event.get("queryStringParameters") or {}
    origin = (event.get("headers") or {}).get("origin", "*")
    
    # Handle OPTIONS preflight requests
    if method == "OPTIONS":
        return _resp(200, {"message": "CORS preflight"}, origin)

    if route.endswith("/sign-put"):
        raw_key = params.get("key")
        if not raw_key:
            return _resp(400, {"error": "missing ?key=input/<file>.txt"}, origin)
        key = urllib.parse.unquote_plus(raw_key)
        supported_extensions = [".txt", ".pdf", ".docx", ".doc"]
        file_extension = key.split(".")[-1].lower()
        if not key.startswith("input/") or f".{file_extension}" not in supported_extensions:
            return _resp(400, {"error": "key must be under input/ and end with .txt, .pdf, .docx, or .doc"}, origin)
        # Determine content type based on file extension
        file_extension = key.split(".")[-1].lower()
        content_type_map = {
            "txt": "text/plain",
            "pdf": "application/pdf", 
            "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "doc": "application/msword"
        }
        content_type = content_type_map.get(file_extension, "application/octet-stream")
        put_url = _presign_put(key, content_type)
        base = os.path.basename(key).rsplit(".", 1)[0]
        out_key = f"{OUTPUT_PREFIX}{base}.mp3"
        get_url_example = _presign_get(out_key)
        return _resp(200, {"put_url": put_url, "expected_output": f"s3://{BUCKET}/{out_key}", "get_url_example": get_url_example}, origin)

    if route.endswith("/sign-get"):
        raw_key = params.get("key")
        if not raw_key:
            return _resp(400, {"error": "missing ?key=output/<file>.mp3"}, origin)
        key = urllib.parse.unquote_plus(raw_key)
        if not key.startswith("output/") or not key.endswith(".mp3"):
            return _resp(400, {"error": "key must be under output/ and end with .mp3"}, origin)
        get_url = _presign_get(key)
        return _resp(200, {"get_url": get_url}, origin)

    return _resp(404, {"error": "route not found"}, origin)
