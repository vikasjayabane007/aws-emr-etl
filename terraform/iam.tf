# ============================================================
# EMR SERVICE ROLE
# ============================================================

resource "aws_iam_role" "emr_service_role" {
  name = "${var.project_name}-${var.environment}-emr-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


# Current AWS managed EMR service policy.
# AmazonElasticMapReduceRole is the older/deprecated V1 policy.

resource "aws_iam_role_policy_attachment" "emr_service_policy" {
  role = aws_iam_role.emr_service_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEMRServicePolicy_v2"
}


# ============================================================
# EMR EC2 ROLE
# ============================================================

# This role is assumed by the EC2 instances running inside
# the EMR cluster.

resource "aws_iam_role" "emr_ec2_role" {
  name = "${var.project_name}-${var.environment}-emr-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


# ============================================================
# EMR EC2 -> S3 POLICY
# ============================================================

# Spark needs:
#
# Data bucket:
#   raw/      -> read
#   curated/  -> read/write
#   gold/     -> read/write
#
# Scripts bucket:
#   read Spark scripts
#
# Logs bucket:
#   EMR/Spark logs

resource "aws_iam_policy" "emr_s3_policy" {
  name = "${var.project_name}-${var.environment}-emr-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      # ------------------------------------------------------
      # List the buckets
      # ------------------------------------------------------

      {
        Sid    = "ListProjectBuckets"
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = [
          aws_s3_bucket.data.arn,
          aws_s3_bucket.scripts.arn,
          aws_s3_bucket.logs.arn
        ]
      },


      # ------------------------------------------------------
      # Read raw input data
      # ------------------------------------------------------

      {
        Sid    = "ReadRawData"
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = [
          "${aws_s3_bucket.data.arn}/raw/*"
        ]
      },


      # ------------------------------------------------------
      # Read/write curated data
      # ------------------------------------------------------

      {
        Sid    = "ManageCuratedData"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = [
          "${aws_s3_bucket.data.arn}/curated/*"
        ]
      },


      # ------------------------------------------------------
      # Read/write gold data
      # ------------------------------------------------------

      {
        Sid    = "ManageGoldData"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = [
          "${aws_s3_bucket.data.arn}/gold/*"
        ]
      },


      # ------------------------------------------------------
      # Read Spark scripts
      # ------------------------------------------------------

      {
        Sid    = "ReadSparkScripts"
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = [
          "${aws_s3_bucket.scripts.arn}/spark/*"
        ]
      },


      # ------------------------------------------------------
      # EMR/Spark logs
      # ------------------------------------------------------

      {
        Sid    = "ManageEMRLogs"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]

        Resource = [
          "${aws_s3_bucket.logs.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}


# ============================================================
# ATTACH S3 POLICY TO EMR EC2 ROLE
# ============================================================

resource "aws_iam_role_policy_attachment" "emr_s3_attachment" {
  role       = aws_iam_role.emr_ec2_role.name
  policy_arn = aws_iam_policy.emr_s3_policy.arn
}


# ============================================================
# EMR EC2 INSTANCE PROFILE
# ============================================================

resource "aws_iam_instance_profile" "emr_instance_profile" {
  name = "${var.project_name}-${var.environment}-emr-instance-profile"

  role = aws_iam_role.emr_ec2_role.name

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}