import json
import boto3
from PIL import Image
import urllib.parse
import io

s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Get the bucket name and object key from the event
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    key = key.replace('+', ' ')  # In case the key contains spaces
    
    # URL-decode the key to handle non-ASCII characters
    key = urllib.parse.unquote(key)

    # Define the new key to save the WebP version (change extension to .webp)
    new_key = key + '.webp'

    try:
        # Get the object from S3
        response = s3.get_object(Bucket=bucket_name, Key=key)
        content_type = response['ContentType']

        # Check if the file is an image (JPEG or PNG)
        if content_type not in ['image/jpeg', 'image/png']:
            print(f"File {key} is not an image. Skipping.")
            return

        # Read the image content
        image_data = response['Body'].read()

        # Open the image using PIL
        image = Image.open(io.BytesIO(image_data))

        # Resize the image
        image = image.resize((800, int(800 * image.height / image.width)))  # Resize to width 800px, maintaining aspect ratio

        # Convert the image to WebP format (optimize for smaller size)
        image_byte_array = io.BytesIO()
        image.save(image_byte_array, format='WEBP', quality=85)  # Adjust quality as needed

        # Upload the WebP compressed image back to S3 under the new key
        s3.put_object(
            Bucket=bucket_name,
            Key=new_key,  # Save with .webp extension
            Body=image_byte_array.getvalue(),
            ContentType='image/webp'
        )

        print(f"Successfully converted and uploaded image as WebP: {new_key}")
        
    except Exception as e:
        print(f"Error processing file {key}: {str(e)}")
        raise e
