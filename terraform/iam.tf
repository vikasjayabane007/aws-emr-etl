# -------------------------------------------------------
# EMR Service Role
# -------------------------------------------------------

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
}


resource "aws_iam_role_policy_attachment" "emr_service_policy" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}


# -------------------------------------------------------
# EMR EC2 Role
# -------------------------------------------------------

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
}


# -------------------------------------------------------
# S3 permissions for Spark
# -------------------------------------------------------

resource "aws_iam_policy" "emr_s3_policy" {
  name = "${var.project_name}-${var.environment}-emr-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      {
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

      {
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = [
          "${aws_s3_bucket.data.arn}/*",
          "${aws_s3_bucket.scripts.arn}/*",
          "${aws_s3_bucket.logs.arn}/*"
        ]
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "emr_s3_attachment" {
  role       = aws_iam_role.emr_ec2_role.name
  policy_arn = aws_iam_policy.emr_s3_policy.arn
}


# -------------------------------------------------------
# EC2 Instance Profile
# -------------------------------------------------------

resource "aws_iam_instance_profile" "emr_instance_profile" {
  name = "${var.project_name}-${var.environment}-emr-instance-profile"

  role = aws_iam_role.emr_ec2_role.name
}