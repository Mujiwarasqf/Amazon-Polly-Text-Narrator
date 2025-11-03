import os
import boto3
import urllib.parse
import io

s3 = boto3.client('s3')
polly = boto3.client('polly')

def extract_text_from_file(file_content, file_extension):
    """Extract text from different file formats"""
    if file_extension == '.txt':
        return file_content.decode('utf-8')
    elif file_extension == '.pdf':
        try:
            from PyPDF2 import PdfReader
            pdf_file = io.BytesIO(file_content)
            reader = PdfReader(pdf_file)
            text = ""
            for page in reader.pages:
                text += page.extract_text() + "\n"
            return text
        except ImportError:
            raise Exception("PyPDF2 not available for PDF processing")
    elif file_extension in ['.docx', '.doc']:
        try:
            from docx import Document
            doc_file = io.BytesIO(file_content)
            doc = Document(doc_file)
            text = ""
            for paragraph in doc.paragraphs:
                text += paragraph.text + "\n"
            return text
        except ImportError:
            raise Exception("python-docx not available for Word processing")
    else:
        raise Exception(f"Unsupported file format: {file_extension}")

BUCKET = os.environ['BUCKET_NAME']
INPUT_PREFIX = os.environ.get('INPUT_PREFIX', 'input/')
OUTPUT_PREFIX = os.environ.get('OUTPUT_PREFIX', 'output/')
VOICE_ID = os.environ.get('VOICE_ID', 'Joanna')
OUTPUT_FORMAT = os.environ.get('OUTPUT_FORMAT', 'mp3')

def lambda_handler(event, context):
    for record in event.get('Records', []):
        key = urllib.parse.unquote_plus(record['s3']['object']['key'])
        bucket = record['s3']['bucket']['name']

        # Check if file is in input prefix and has supported extension
        supported_extensions = ['.txt', '.pdf', '.docx', '.doc']
        file_extension = os.path.splitext(key)[1].lower()
        
        if not key.startswith(INPUT_PREFIX) or file_extension not in supported_extensions:
            print(f"Skipping key: {key} (unsupported format or wrong location)")
            continue

        obj = s3.get_object(Bucket=bucket, Key=key)
        file_content = obj['Body'].read()
        
        try:
            text = extract_text_from_file(file_content, file_extension)
        except Exception as e:
            print(f"Error extracting text from {key}: {str(e)}")
            continue

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
