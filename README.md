# S3 Presigned URL File Upload Demo

This project demonstrates how to use AWS S3 presigned URLs to upload files directly from a frontend application to an S3 bucket.

## Workflow

Upload a file:

1. frontend calls POST /file api
2. backend receives the request and generate the presigned-post url with conditions
3. frontend uses the presigned-post url to upload file to s3 bucket
4. s3 bucket event notification triggers compressImg lambda function to create .webp file

Get the file:

5. frontend calls GET /file/:objectKey
6. backend generate the presigned GetObjectCommand url (get .webp if exists)
7. frontend uses the presigned url to get the file

## How to run

```sh
# run on local environment
docker compose up -d --build
```

Local environment uses [localstack](https://www.localstack.cloud/), which does NOT support condition checking.

---

```bash
# deploy to aws
sam build && sam deploy --guided
```

There will be an ApiGateway url in the output. Change the .env file in the frontend with the ApiGateway url to upload file to AWS S3 bucket

```bash
# use terraform
cd terraform
make
```

## Hints

1. Includes the Content-Type in Fields if it is a condition. Same for other fields.

```javascript
const { url, fields } = await createPresignedPost(s3Client, {
    Bucket: process.env.AWS_S3_BUCKET_NAME,
    Key: objectKey,
    Expires: 3600,
    Fields: {
        'Content-Type': fileType,
    },
    Conditions: [
        ['content-length-range', 0, 5 * 1024 * 1024], // up to 5 MB
        ["starts-with", "$Content-Type", "image/"],
    ],
});
```

2. Refer s3 bucket in a lambda function used for the bucket event could cause Circular Dependency issue. Check the post "[How do I resolve circular dependencies with AWS SAM templates in CloudFormation?](https://repost.aws/knowledge-center/cloudformation-circular-dependency-sam)". It needs to use constant bucket name.

```yaml
Resources:
  ImageUploadBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub "${AWS::StackName}-${BucketName}-${AWS::AccountId}-${AWS::Region}"

  ImageProcessingFunction:
    Type: AWS::Serverless::Function
    Properties: 
      Policies:
        - S3ReadPolicy:
            BucketName: !Sub "${AWS::StackName}-${BucketName}-${AWS::AccountId}-${AWS::Region}"
        - S3WritePolicy:
            BucketName: !Sub "${AWS::StackName}-${BucketName}-${AWS::AccountId}-${AWS::Region}"
```

3. If you encouter 403 error during docker build when using terraform, check the docker setting "useContainerdSnapshotter". The value should be false.




