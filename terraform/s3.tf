# ============================================================
# S3 - Data Bucket
# ============================================================

resource "aws_s3_bucket" "data" {
  bucket = "${var.project_name}-${var.environment}-data"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


# ============================================================
# S3 - Spark Scripts Bucket
# ============================================================

resource "aws_s3_bucket" "scripts" {
  bucket = "${var.project_name}-${var.environment}-scripts"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


# ============================================================
# S3 - EMR Logs Bucket
# ============================================================

resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-${var.environment}-logs"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


# ============================================================
# Upload Spark Transformation Script
# ============================================================

resource "aws_s3_object" "transform_script" {
  bucket = aws_s3_bucket.scripts.id

  key = "spark/transform.py"

  source = "${path.module}/../spark/transform.py"

  etag = filemd5("${path.module}/../spark/transform.py")

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


# ============================================================
# Upload Spark Aggregation Script
# ============================================================

resource "aws_s3_object" "aggregate_script" {
  bucket = aws_s3_bucket.scripts.id

  key = "spark/aggregate.py"

  source = "${path.module}/../spark/aggregate.py"

  etag = filemd5("${path.module}/../spark/aggregate.py")

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}