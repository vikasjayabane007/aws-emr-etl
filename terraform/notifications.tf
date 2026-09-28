# ============================================================
# S3 -> Lambda Notification
# ============================================================

# Allow the S3 data bucket to invoke the validation Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.validate_file.function_name
  principal     = "s3.amazonaws.com"

  # Only our data bucket can invoke this Lambda
  source_arn = aws_s3_bucket.data.arn
}


# Configure the S3 bucket to invoke Lambda when a CSV
# file is uploaded under the raw/ prefix
resource "aws_s3_bucket_notification" "raw_file_notification" {
  bucket = aws_s3_bucket.data.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.validate_file.arn

    events = [
      "s3:ObjectCreated:*"
    ]

    filter_prefix = "raw/"
    filter_suffix = ".csv"
  }

  # S3 notification creation requires Lambda invocation
  # permission to exist first.
  depends_on = [
    aws_lambda_permission.allow_s3
  ]
}