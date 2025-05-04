import boto3
import os
import sys
import uuid
import json
from urllib.parse import unquote_plus
from PIL import Image
import PIL.Image
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')

def resize_image(image_path, resized_path):
    try:
        with Image.open(image_path) as image:
            image.thumbnail((128, 128))
            image.save(resized_path)
        return True
    except Exception as e:
        logger.error(f"Error resizing image: {str(e)}")
        return False

def lambda_handler(event, context):
    try:
        logger.info(f"Received event: {event}")
        
        if 'Records' in event:

            if 'eventSource' in event['Records'][0] and event['Records'][0]['eventSource'] == 'aws:sqs':
                for record in event['Records']:

                    body = json.loads(record['body'])
                    logger.info(f"SQS message body: {body}")
                    
                    if 'Message' in body:
                        s3_event = json.loads(body['Message'])
                        logger.info(f"SNS message content: {s3_event}")
                        
                        if 'Records' in s3_event:
                            for s3_record in s3_event['Records']:
                                if 's3' in s3_record:
                                    process_s3_record(s3_record)

            elif 's3' in event['Records'][0]:
                for record in event['Records']:
                    process_s3_record(record)
        else:
            logger.error("Event doesn't contain Records key")
            logger.error(f"Event structure: {event}")
            return {
                'statusCode': 400,
                'body': 'Invalid event structure'
            }
        
        return {
            'statusCode': 200,
            'body': 'Thumbnail creation completed successfully'
        }
        
    except Exception as e:
        logger.error(f"Lambda execution failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': f'Error creating thumbnail: {str(e)}'
        }

def process_s3_record(record):
    """Process a single S3 record to create a thumbnail"""
    try:
        bucket = record['s3']['bucket']['name']
        key = unquote_plus(record['s3']['object']['key'])
        
        if 'resized-' in key:
            logger.info(f"Skipping already processed file: {key}")
            return
            
        tmpkey = key.replace('/', '_')
        download_path = f"/tmp/{uuid.uuid4()}-{tmpkey}"
        upload_path = f"/tmp/resized-{tmpkey}"
        
        try:
            logger.info(f"Downloading {key} from bucket {bucket}")
            s3_client.download_file(bucket, key, download_path)
            
            if resize_image(download_path, upload_path):
                destination_bucket = os.environ.get('DESTINATION_BUCKET', f"{bucket}-resized")
                resized_key = f"resized-{key}"
                
                logger.info(f"Uploading resized image to {destination_bucket}/{resized_key}")
                s3_client.upload_file(upload_path, destination_bucket, resized_key)
                logger.info(f"Successfully processed {key}")
            else:
                logger.error(f"Failed to resize {key}")
        
        except Exception as e:
            logger.error(f"Error processing {key}: {str(e)}")
            raise
        
        finally:
            if os.path.exists(download_path):
                os.remove(download_path)
            if os.path.exists(upload_path):
                os.remove(upload_path)
                
    except Exception as e:
        logger.error(f"Error processing S3 record: {str(e)}")
        logger.error(f"Record content: {record}")