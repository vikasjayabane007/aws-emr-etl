variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "emr-etl-pipeline"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "emr_release_label" {
  description = "EMR release"
  type        = string
  default     = "emr-7.10.0"
}

variable "emr_master_instance_type" {
  type    = string
  default = "m5.xlarge"
}

variable "emr_core_instance_type" {
  type    = string
  default = "m5.xlarge"
}