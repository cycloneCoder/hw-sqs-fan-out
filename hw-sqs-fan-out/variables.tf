variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "source_bucket_name" {
  description = "Name of the source S3 bucket where images will be uploaded"
  type        = string
  default     = "img-upload-6546546"
}

variable "destination_bucket_name" {
  description = "Name of the destination S3 bucket where thumbnails will be stored"
  type        = string
  default     = "img-upload-6546546-resized"
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue"
  type        = string
  default     = "new-image-queue"
}

variable "sns_topic_name" {
  description = "Name of the SNS topic"
  type        = string
  default     = "sqs-fan-out-hw"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "generate-thumbnail1-tf"
}

variable "lambda_memory_size" {
  description = "Amount of memory in MB your Lambda Function can use at runtime"
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "The amount of time your Lambda Function has to run in seconds"
  type        = number
  default     = 15
}
