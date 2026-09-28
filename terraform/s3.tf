# ============================================================
# S3 DATA BUCKET
# Stores raw, curated, and gold data
# ============================================================

resource "aws_s3_bucket" "data" {
  bucket        = "${var.project_name}-${var.environment}-data"
  force_destroy = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


# ============================================================
# S3 SCRIPTS BUCKET
# Stores Spark scripts used by EMR
# ============================================================

resource "aws_s3_bucket" "scripts" {
  bucket        = "${var.project_name}-${var.environment}-scripts"
  force_destroy = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


# ============================================================
# S3 LOGS BUCKET
# Stores EMR/Spark logs
# ============================================================

resource "aws_s3_bucket" "logs" {
  bucket        = "${var.project_name}-${var.environment}-logs"
  force_destroy = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


# ============================================================
# UPLOAD TRANSFORM SPARK SCRIPT
# ============================================================

resource "aws_s3_object" "transform_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "spark/transform.py"

  source = "${path.module}/../spark/transform.py"
  etag   = filemd5("${path.module}/../spark/transform.py")

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


# ============================================================
# UPLOAD AGGREGATE SPARK SCRIPT
# ============================================================

resource "aws_s3_object" "aggregate_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "spark/aggregate.py"

  source = "${path.module}/../spark/aggregate.py"
  etag   = filemd5("${path.module}/../spark/aggregate.py")

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}