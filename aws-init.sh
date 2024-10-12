export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

aws s3api create-bucket --endpoint http://localhost:4566 --region us-east-1 --bucket demo 
aws s3api put-bucket-cors --endpoint http://localhost:4566 --region us-east-1  --bucket demo --cors-configuration '{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
      "AllowedHeaders": ["*"],
      "MaxAgeSeconds": 3000,
      "ExposeHeaders": ["ETag"]
    }
  ]
}'