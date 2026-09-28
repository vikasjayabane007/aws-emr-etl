# ============================================================
# Step Functions IAM Role
# ============================================================

resource "aws_iam_role" "step_functions_role" {
  name = "${var.project_name}-${var.environment}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "states.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}


# ============================================================
# Step Functions -> EMR Permissions
# ============================================================

resource "aws_iam_policy" "step_functions_emr_policy" {
  name = "${var.project_name}-${var.environment}-step-functions-emr-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
  "elasticmapreduce:AddJobFlowSteps",
  "elasticmapreduce:DescribeStep",
  "elasticmapreduce:DescribeCluster",
  "elasticmapreduce:CancelSteps"
]

        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "step_functions_emr_attachment" {
  role       = aws_iam_role.step_functions_role.name
  policy_arn = aws_iam_policy.step_functions_emr_policy.arn
}


# ============================================================
# Step Functions State Machine
# ============================================================

resource "aws_sfn_state_machine" "etl_pipeline" {

  name     = "${var.project_name}-${var.environment}-etl-pipeline"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = jsonencode({

    Comment = "Premium ETL Pipeline using EMR and Spark"

    StartAt = "TransformData"

    States = {

      # ======================================================
      # STEP 1 - TRANSFORM
      # ======================================================

      TransformData = {

        Type = "Task"

        Resource = "arn:aws:states:::elasticmapreduce:addStep.sync"

        Parameters = {

          ClusterId = aws_emr_cluster.etl_cluster.id

          Step = {

            Name = "Transform Raw Premium Data"

            ActionOnFailure = "CONTINUE"

            HadoopJarStep = {

              Jar = "command-runner.jar"

              "Args.$" = "States.Array('spark-submit', 's3://${aws_s3_bucket.scripts.bucket}/spark/transform.py', '--input-bucket', $.bucket, '--input-key', $.key, '--output-path', 's3://${aws_s3_bucket.data.bucket}/curated/premiums/')"
            }
          }
        }

        Next = "AggregateData"

        Catch = [
          {
            ErrorEquals = [
              "States.ALL"
            ]

            ResultPath = "$.transform_error"

            Next = "PipelineFailed"
          }
        ]
      }


      # ======================================================
      # STEP 2 - AGGREGATE
      # ======================================================

      AggregateData = {

        Type = "Task"

        Resource = "arn:aws:states:::elasticmapreduce:addStep.sync"

        Parameters = {

          ClusterId = aws_emr_cluster.etl_cluster.id

          Step = {

            Name = "Aggregate Premium Data"

            ActionOnFailure = "CONTINUE"

            HadoopJarStep = {

              Jar = "command-runner.jar"

              Args = [
                "spark-submit",

                "s3://${aws_s3_bucket.scripts.bucket}/spark/aggregate.py",

                "--input-path",
                "s3://${aws_s3_bucket.data.bucket}/curated/premiums/",

                "--output-path",
                "s3://${aws_s3_bucket.data.bucket}/gold/premiums/"
              ]
            }
          }
        }

        Next = "PipelineSucceeded"

        Catch = [
          {
            ErrorEquals = [
              "States.ALL"
            ]

            ResultPath = "$.aggregation_error"

            Next = "PipelineFailed"
          }
        ]
      }


      # ======================================================
      # SUCCESS
      # ======================================================

      PipelineSucceeded = {
        Type = "Succeed"
      }


      # ======================================================
      # FAILURE
      # ======================================================

      PipelineFailed = {
        Type  = "Fail"
        Error = "ETLPipelineFailed"
        Cause = "EMR Spark processing failed"
      }
    }
  })


  depends_on = [
    aws_iam_role_policy_attachment.step_functions_emr_attachment
  ]
}