resource "aws_emr_cluster" "etl_cluster" {

  name          = "${var.project_name}-${var.environment}-cluster"
  release_label = var.emr_release_label

  applications = [
    "Spark"
  ]

  service_role = aws_iam_role.emr_service_role.arn

  log_uri = "s3://${aws_s3_bucket.logs.bucket}/emr/"

  ec2_attributes {

    subnet_id = aws_subnet.emr_subnet.id

    instance_profile = aws_iam_instance_profile.emr_instance_profile.arn
  }


  # ----------------------------
  # Primary node
  # ----------------------------

  master_instance_group {
    instance_type  = var.emr_master_instance_type
    instance_count = 1
  }


  # ----------------------------
  # Worker nodes
  # ----------------------------

  core_instance_group {
    instance_type  = var.emr_core_instance_type
    instance_count = 2
  }


  # Keep alive because Step Functions
  # will submit Spark jobs later

  keep_job_flow_alive_when_no_steps = true

  termination_protection = false


  tags = {
    Project     = var.project_name
    Environment = var.environment

    "for-use-with-amazon-emr-managed-policies" = "true"
  }
}