import os
import boto3
import urllib.parse

s3 = boto3.client('s3')
polly = boto3.client('polly')

BUCKET = os.environ['BUCKET_NAME']
INPUT_PREFIX = os.environ.get('INPUT_PREFIX', 'input/')
OUTPUT_PREFIX = os.environ.get('OUTPUT_PREFIX', 'output/')
VOICE_ID = os.environ.get('VOICE_ID', 'Joanna')
OUTPUT_FORMAT = os.environ.get('OUTPUT_FORMAT', 'mp3')

def lambda_handler(event, context):
    for record in event.get('Records', []):
        key = urllib.parse.unquote_plus(record['s3']['object']['key'])
        bucket = record['s3']['bucket']['name']

        if not key.startswith(INPUT_PREFIX) or not key.endswith('.txt'):
            print(f"Skipping key: {key}")
            continue

        obj = s3.get_object(Bucket=bucket, Key=key)
        text = obj['Body'].read().decode('utf-8')

        # Optional: per-file voice via metadata 'x-amz-meta-voice'
        try:
            head = s3.head_object(Bucket=bucket, Key=key)
            voice = head.get('Metadata', {}).get('voice', VOICE_ID)
        except Exception:
            voice = VOICE_ID

        response = polly.synthesize_speech(
            Text=text,
            OutputFormat=OUTPUT_FORMAT,
            VoiceId=voice
        )

        audio_stream = response.get('AudioStream').read()
        base = os.path.basename(key).rsplit('.', 1)[0]
        out_key = f"{OUTPUT_PREFIX}{base}.mp3"

        s3.put_object(
            Bucket=bucket,
            Key=out_key,
            Body=audio_stream,
            ContentType='audio/mpeg'
        )
        print(f"Wrote {out_key}")
    return {"status": "ok"}
