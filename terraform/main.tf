provider "aws" {
  region = var.region
  default_tags {
    tags = var.tags
  }
}

resource "random_string" "resource_suffix" {
  length  = 8
  special = false
  upper   = false
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

#------------------------------------------------#
# S3 bucket to store uploaded images             #
#------------------------------------------------#

resource "aws_s3_bucket" "image_upload_bucket" {
  bucket = "${var.resource_prefix}-image-upload-bucket-${random_string.resource_suffix.result}"
}

resource "aws_s3_bucket_cors_configuration" "image_upload_bucket_cors" {
  bucket = aws_s3_bucket.image_upload_bucket.bucket

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "DELETE"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

#------------------------------------------------#
# Express API Docker image and Lambda function   #
#------------------------------------------------#

resource "aws_ecr_repository" "express_api_ecr_repo" {
  name = "${var.resource_prefix}-${random_string.resource_suffix.result}/${var.image_name}-${random_string.resource_suffix.result}"
}

data "external" "docker_image_id" {
  program = ["sh", "-c", "docker inspect --format='{{json .Id}}' ${var.image_name}:${var.image_tag} | jq -n '{output: input}'"]
}

resource "null_resource" "upload_express_image" {
  triggers = {
    image_hash = data.external.docker_image_id.result.output
  }

  provisioner "local-exec" {
    command = <<EOF
        set -e
        aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.express_api_ecr_repo.repository_url}
        docker tag ${var.image_name}:${var.image_tag} ${aws_ecr_repository.express_api_ecr_repo.repository_url}:${var.image_tag}
        docker push ${aws_ecr_repository.express_api_ecr_repo.repository_url}:${var.image_tag}
    EOF
  }

  depends_on = [aws_ecr_repository.express_api_ecr_repo]

}

resource "aws_lambda_function" "express_app" {
  function_name = "${var.resource_prefix}-express-app-${random_string.resource_suffix.result}"
  image_uri     = "${aws_ecr_repository.express_api_ecr_repo.repository_url}:${var.image_tag}"
  role          = aws_iam_role.express_app_role.arn
  package_type  = "Image"
  memory_size   = 1024
  timeout       = 30
  architectures = ["arm64"]
  environment {
    variables = {
      API_STAGE_NAME       = var.api_stage_name
      AWS_S3_BUCKET_NAME   = aws_s3_bucket.image_upload_bucket.bucket
      AWS_S3_BUCKET_REGION = var.region
    }
  }

  depends_on = [null_resource.upload_express_image]
}

resource "aws_iam_role" "express_app_role" {
  name = "${var.resource_prefix}-express-app-role-${random_string.resource_suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_iam_policy" "express_app_policy" {
  name = "${var.resource_prefix}-s3-full-access-${aws_s3_bucket.image_upload_bucket.bucket}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration"
        ]
        Effect   = "Allow"
        Resource = aws_s3_bucket.image_upload_bucket.arn
      },
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:DeleteObjectTagging",
          "s3:DeleteObjectVersionTagging",
          "s3:GetObjectTagging",
          "s3:GetObjectVersionTagging",
          "s3:PutObjectTagging",
          "s3:PutObjectVersionTagging"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.image_upload_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "express_app_policy_attachment" {
  role       = aws_iam_role.express_app_role.name
  policy_arn = aws_iam_policy.express_app_policy.arn
}

resource "aws_iam_role_policy_attachment" "express_app_basic_execution_role_attachment" {
  role       = aws_iam_role.express_app_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

#------------------------------------------------#
# API Gateway to expose the Express API          #
#------------------------------------------------#

resource "aws_apigatewayv2_api" "backend_api" {
  name          = "${var.resource_prefix}-BackendApi-${random_string.resource_suffix.result}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"] 
    allow_methods = ["GET", "POST", "OPTIONS", "PUT", "DELETE"]
    allow_headers = ["Content-Type", "Authorization"]
    expose_headers = ["Authorization"]
    max_age = 86400
  }
}

resource "aws_apigatewayv2_stage" "backend_api_stage" {
  api_id      = aws_apigatewayv2_api.backend_api.id
  name        = var.api_stage_name
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.backend_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.express_app.invoke_arn
}

resource "aws_apigatewayv2_route" "proxy_route" {
  api_id    = aws_apigatewayv2_api.backend_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.express_app.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.backend_api.execution_arn}/*"
}

#------------------------------------------------#
# Lambda function to compress images             #
#------------------------------------------------#

data "local_file" "lambda_package_hash" {
  filename = "../.terraform_build/lambda_package.sha256sum"
}

resource "aws_lambda_function" "image_process_function" {
  function_name    = "${var.resource_prefix}-compress-image-${random_string.resource_suffix.result}"
  handler          = "compressImg.lambda_handler"
  runtime          = "python3.9"
  memory_size      = 1024
  timeout          = 30
  role             = aws_iam_role.image_process_lambda_role.arn
  filename         = "../.terraform_build/lambda_package.zip"
  architectures    = ["arm64"]
  source_code_hash = data.local_file.lambda_package_hash.content
  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.image_upload_bucket.bucket
    }
  }
}

data "aws_iam_policy_document" "s3_access_policy" {
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:PostObject"]
    resources = ["${aws_s3_bucket.image_upload_bucket.arn}/*"]
  }
}

resource "aws_iam_role" "image_process_lambda_role" {
  name = "${var.resource_prefix}-image-process-lambda-role-${random_string.resource_suffix.result}"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_iam_policy" "s3_access_policy" {
  name   = "${var.resource_prefix}-s3-access-policy-${aws_s3_bucket.image_upload_bucket.bucket}"
  policy = data.aws_iam_policy_document.s3_access_policy.json
}

resource "aws_iam_role_policy_attachment" "s3_access_policy_attachment" {
  role       = aws_iam_role.image_process_lambda_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "image_process_basic_execution_role_attachment" {
  role       = aws_iam_role.image_process_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_process_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.image_upload_bucket.arn
}

resource "aws_s3_bucket_notification" "image_upload_bucket_notification" {
  bucket = aws_s3_bucket.image_upload_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_process_function.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_process_function.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpeg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_process_function.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".png"
  }

  depends_on = [
    aws_lambda_function.image_process_function,
    aws_s3_bucket.image_upload_bucket,
    aws_lambda_permission.allow_s3_invoke
  ]
}

output "express_api" {
  description = "API Gateway endpoint URL for the stage"
  value       = "${aws_apigatewayv2_api.backend_api.api_endpoint}/${var.api_stage_name}"
}