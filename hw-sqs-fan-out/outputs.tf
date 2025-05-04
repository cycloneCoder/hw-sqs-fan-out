output "source_bucket_name" {
  description = "The name of the source S3 bucket"
  value       = aws_s3_bucket.source_bucket.bucket
}

output "destination_bucket_name" {
  description = "The name of the destination S3 bucket"
  value       = aws_s3_bucket.destination_bucket.bucket
}

output "sns_topic_arn" {
  description = "The ARN of the SNS topic"
  value       = aws_sns_topic.image_processing_topic.arn
}

output "sqs_queue_url" {
  description = "The URL of the SQS queue"
  value       = aws_sqs_queue.image_processing_queue.url
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.thumbnail_generator.arn
}

output "lambda_function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.thumbnail_generator.function_name
}