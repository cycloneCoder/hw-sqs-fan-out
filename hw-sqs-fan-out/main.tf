resource "aws_s3_bucket" "source_bucket" {
  bucket = var.source_bucket_name
}

resource "aws_s3_bucket_server_side_encryption_configuration" "source_bucket_encryption" {
  bucket = aws_s3_bucket.source_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "source_bucket_public_access_block" {
  bucket                  = aws_s3_bucket.source_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "source_bucket_ownership" {
  bucket = aws_s3_bucket.source_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket" "destination_bucket" {
  bucket = var.destination_bucket_name
}

resource "aws_s3_bucket_server_side_encryption_configuration" "destination_bucket_encryption" {
  bucket = aws_s3_bucket.destination_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "destination_bucket_public_access_block" {
  bucket                  = aws_s3_bucket.destination_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "destination_bucket_ownership" {
  bucket = aws_s3_bucket.destination_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_sns_topic" "image_processing_topic" {
  name = var.sns_topic_name
}

resource "aws_sqs_queue" "image_processing_queue" {
  name                       = var.sqs_queue_name
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 0
  visibility_timeout_seconds = 30
  sqs_managed_sse_enabled    = true
}

resource "aws_sqs_queue_policy" "image_processing_queue_policy" {
  queue_url = aws_sqs_queue.image_processing_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.image_processing_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.image_processing_topic.arn
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "image_processing_subscription" {
  topic_arn = aws_sns_topic.image_processing_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.image_processing_queue.arn
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-function-admin-access"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_admin_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "null_resource" "install_dependencies" {
  provisioner "local-exec" {
    command = "pip install Pillow -t ${path.module}/src/"
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda_function.zip"
  depends_on  = [null_resource.install_dependencies]
}

resource "aws_lambda_function" "thumbnail_generator" {
  function_name    = var.lambda_function_name
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      DESTINATION_BUCKET = aws_s3_bucket.destination_bucket.bucket
    }
  }

  ephemeral_storage {
    size = 512
  }
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 14
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.source_bucket.id

  topic {
    topic_arn     = aws_sns_topic.image_processing_topic.arn
    events        = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sns_topic.image_processing_topic]
}

resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  event_source_arn = aws_sqs_queue.image_processing_queue.arn
  function_name    = aws_lambda_function.thumbnail_generator.arn
  batch_size       = 10
  enabled          = true
}