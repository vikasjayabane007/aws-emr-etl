# ============================================================
# Package Lambda Python Code
# ============================================================

data "archive_file" "validation_lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda/validate_file.py"
  output_path = "${path.module}/validate_file.zip"
}


# ============================================================
# Lambda IAM Role
# ============================================================

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}


# ============================================================
# CloudWatch Logs Permission
# ============================================================

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# ============================================================
# Lambda S3 Policy
# Allows Lambda to inspect files uploaded to raw/
# ============================================================

resource "aws_iam_policy" "lambda_s3_policy" {
  name = "${var.project_name}-${var.environment}-lambda-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      # Allow Lambda to list the data bucket
      {
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = [
          aws_s3_bucket.data.arn
        ]
      },

      # Allow Lambda to read raw files
      {
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = [
          "${aws_s3_bucket.data.arn}/raw/*"
        ]
      }
    ]
  })
}


# ============================================================
# Attach S3 Policy to Lambda Role
# ============================================================

resource "aws_iam_role_policy_attachment" "lambda_s3_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}


# ============================================================
# Lambda -> Step Functions Policy
# Allows Lambda to start the ETL state machine
# ============================================================

resource "aws_iam_policy" "lambda_step_functions_policy" {
  name = "${var.project_name}-${var.environment}-lambda-sfn-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "states:StartExecution"
        ]

        Resource = aws_sfn_state_machine.etl_pipeline.arn
      }
    ]
  })
}


# ============================================================
# Attach Step Functions Policy to Lambda Role
# ============================================================

resource "aws_iam_role_policy_attachment" "lambda_step_functions_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_step_functions_policy.arn
}


# ============================================================
# Lambda Function
# ============================================================

resource "aws_lambda_function" "validate_file" {

  function_name = "${var.project_name}-${var.environment}-validate-file"

  role = aws_iam_role.lambda_role.arn

  # ----------------------------------------------------------
  # Runtime
  # ----------------------------------------------------------

  runtime = "python3.13"
  handler = "validate_file.lambda_handler"


  # ----------------------------------------------------------
  # Deployment Package
  # ----------------------------------------------------------

  filename = data.archive_file.validation_lambda.output_path

  source_code_hash = data.archive_file.validation_lambda.output_base64sha256


  # ----------------------------------------------------------
  # Lambda Configuration
  # ----------------------------------------------------------

  timeout     = 30
  memory_size = 256


  # ----------------------------------------------------------
  # Environment Variables
  # ----------------------------------------------------------

  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.etl_pipeline.arn
    }
  }


  # ----------------------------------------------------------
  # Tags
  # ----------------------------------------------------------

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }


  # Make sure permissions are attached before Lambda
  # becomes operational
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_s3_attachment,
    aws_iam_role_policy_attachment.lambda_step_functions_attachment
  ]
}