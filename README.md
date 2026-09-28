# AWS EMR Serverless ETL Pipeline

A hands-on AWS data engineering project that demonstrates an event-driven ETL pipeline using **Amazon S3, AWS Lambda, AWS Step Functions, Amazon EMR, Apache Spark, PySpark, IAM, and Terraform**.

The pipeline ingests raw insurance premium data from Amazon S3, validates incoming files with Lambda, orchestrates Spark processing through Step Functions, transforms the data on an EMR cluster, and writes curated and aggregated datasets back to S3 in Parquet format.

> **Note:** Despite the repository title, the current implementation uses a provisioned Amazon EMR cluster rather than EMR Serverless.

---

## Architecture

```text
                    CSV Upload
                        │
                        ▼
                ┌───────────────┐
                │ Amazon S3     │
                │ raw/premiums/ │
                └───────┬───────┘
                        │
                 ObjectCreated Event
                        │
                        ▼
                ┌───────────────┐
                │ AWS Lambda    │
                │ File Validator│
                └───────┬───────┘
                        │
                 Start Execution
                        │
                        ▼
                ┌─────────────────┐
                │ Step Functions  │
                └────────┬────────┘
                         │
              ┌──────────┴──────────┐
              │                     │
              ▼                     ▼
       TransformData          AggregateData
              │                     │
              ▼                     ▼
       ┌────────────────────────────────┐
       │       Amazon EMR + Spark       │
       │           PySpark              │
       └───────────────┬────────────────┘
                       │
              ┌────────┴─────────┐
              │                  │
              ▼                  ▼
       curated/premiums/   gold/premiums/
          Parquet             Parquet
```

---

## AWS Services

| Service | Purpose |
|---|---|
| Amazon S3 | Raw, curated, gold, scripts, and EMR log storage |
| AWS Lambda | Validates uploaded files and starts the workflow |
| AWS Step Functions | Orchestrates Spark transformation and aggregation |
| Amazon EMR | Runs distributed Apache Spark workloads |
| Apache Spark / PySpark | Data transformation and aggregation |
| AWS IAM | Least-privilege service permissions |
| Amazon VPC | Network environment for the EMR cluster |
| AWS Glue Data Catalog | Catalog database for analytical datasets |
| Terraform | Infrastructure as Code |

---

## Pipeline Flow

### 1. Raw data ingestion

A CSV file is uploaded to:

```text
s3://emr-etl-pipeline-dev-data/raw/premiums/
```

The S3 `ObjectCreated` event automatically invokes the validation Lambda function.

Example input:

```csv
premium_id,policy_id,premium_amount,payment_date,state,product_type
PR001,POL1001,1250.00,2026-09-27,MO,Life
PR002,POL1002,850.50,2026-09-27,KS,Life
PR003,POL1003,2100.00,2026-09-27,MO,Annuity
PR004,POL1004,975.25,2026-09-27,KS,Life
PR005,POL1005,1500.00,2026-09-27,TX,Annuity
```

### 2. Lambda validation

The Lambda function performs lightweight validation before processing.

It verifies:

- The uploaded object is a CSV file.
- The file is not empty.
- S3 object metadata can be retrieved.
- The bucket, key, and file size are passed to Step Functions.

Lambda intentionally does not perform the large-scale ETL workload.

---

## Step Functions Orchestration

After validation, Lambda starts the Step Functions state machine.

```text
TransformData
      │
      ▼
AggregateData
      │
      ▼
PipelineSucceeded
```

If an EMR Spark step fails:

```text
PipelineFailed
```

Step Functions submits Spark jobs to the existing EMR cluster using the EMR service integration.

---

## Spark Transformation

The first Spark job executes:

```text
spark/transform.py
```

It reads the uploaded CSV directly from S3.

Processing includes:

- CSV parsing
- Schema inference
- Duplicate removal using `premium_id`
- Casting `premium_amount` to `decimal(18,2)`
- Converting `payment_date` to a date
- Filtering invalid/null records
- Adding a processing timestamp
- Converting CSV to Parquet
- Partitioning by `payment_date`

Output:

```text
s3://emr-etl-pipeline-dev-data/curated/premiums/
```

Example:

```text
curated/
└── premiums/
    └── payment_date=2026-09-27/
        └── part-xxxxx.snappy.parquet
```

---

## Spark Aggregation

The second Spark job executes:

```text
spark/aggregate.py
```

It reads the curated Parquet dataset and groups records by:

```text
payment_date
state
product_type
```

Metrics generated include:

```text
total_premium
premium_transactions
unique_policies
```

Example logical output:

| payment_date | state | product_type | total_premium | premium_transactions | unique_policies |
|---|---|---|---:|---:|---:|
| 2026-09-27 | KS | Life | 1825.75 | 2 | 2 |
| 2026-09-27 | MO | Life | 1250.00 | 1 | 1 |
| 2026-09-27 | MO | Annuity | 2100.00 | 1 | 1 |
| 2026-09-27 | TX | Annuity | 1500.00 | 1 | 1 |

Gold output:

```text
s3://emr-etl-pipeline-dev-data/gold/premiums/
```

---

## Repository Structure

```text
aws-emr-etl/
│
├── lambda/
│   └── validate_file.py
│
├── spark/
│   ├── transform.py
│   └── aggregate.py
│
├── terraform/
│   ├── providers.tf
│   ├── variables.tf
│   ├── networking.tf
│   ├── s3.tf
│   ├── iam.tf
│   ├── lambda.tf
│   ├── emr.tf
│   ├── step-functions.tf
│   ├── notifications.tf
│   └── glue.tf
│
├── .gitignore
└── README.md
```

---

## Terraform

The AWS infrastructure is provisioned using Terraform.

Initialize Terraform:

```bash
cd terraform
terraform init
```

Format:

```bash
terraform fmt
```

Validate:

```bash
terraform validate
```

Preview infrastructure changes:

```bash
terraform plan
```

Deploy:

```bash
terraform apply
```

Terraform provisions resources including:

- S3 buckets
- IAM roles and policies
- VPC
- Subnet
- Internet Gateway
- Route table
- EMR cluster
- Lambda function
- Step Functions state machine
- S3 event notification
- Glue Data Catalog resources

---

## Running the Pipeline

Create a sample file named:

```text
test-premiums.csv
```

Upload it:

```bash
aws s3 cp test-premiums.csv \
  s3://emr-etl-pipeline-dev-data/raw/premiums/test-premiums.csv \
  --profile etl-dev \
  --region us-east-2
```

No additional command is required.

The upload triggers:

```text
S3
 ↓
Lambda
 ↓
Step Functions
 ↓
EMR / Spark Transformation
 ↓
Curated Parquet
 ↓
EMR / Spark Aggregation
 ↓
Gold Parquet
```

---

## Checking Curated Output

```bash
aws s3 ls \
  s3://emr-etl-pipeline-dev-data/curated/premiums/ \
  --recursive \
  --profile etl-dev \
  --region us-east-2
```

---

## Checking Gold Output

```bash
aws s3 ls \
  s3://emr-etl-pipeline-dev-data/gold/premiums/ \
  --recursive \
  --profile etl-dev \
  --region us-east-2
```

---

## Glue Data Catalog

The project includes Terraform configuration for a Glue Data Catalog database and a crawler intended to catalog the gold Parquet dataset.

Target:

```text
s3://emr-etl-pipeline-dev-data/gold/premiums/
```

The intended analytics architecture is:

```text
Gold Parquet
     │
     ▼
Glue Data Catalog
     │
     ▼
Amazon Athena
     │
     ▼
SQL Analytics
```

### Current limitation

During development, creation of the Glue crawler returned an AWS `AccessDeniedException` stating that the account was denied access.

IAM policy simulation confirmed that the deployment identity had both:

```text
glue:CreateCrawler → allowed
iam:PassRole       → allowed
```

Therefore, the crawler portion was not successfully completed during the initial implementation.

The core ETL pipeline through gold Parquet output was successfully executed independently of the crawler.

---

## Infrastructure Lessons

This project also demonstrates several operational AWS concepts.

### Terraform state and drift

Terraform tracks deployed resources in its state.

If a Terraform-managed EMR cluster is manually terminated in AWS, a subsequent:

```bash
terraform apply
```

detects that the cluster is missing and attempts to recreate it.

For infrastructure managed by Terraform, lifecycle operations should generally be performed through Terraform rather than manually through the AWS Console.

### IAM PassRole

The EMR service role requires permission to pass the EC2 instance role used by cluster instances.

The project therefore explicitly grants:

```text
iam:PassRole
```

for the custom EMR EC2 role.

### EMR service policy

The EMR service role uses:

```text
AmazonEMRServicePolicy_v2
```

Resources used by the EMR managed policy are tagged appropriately with:

```text
for-use-with-amazon-emr-managed-policies = true
```

### EC2 service quotas

EMR cluster sizing is subject to the AWS account's EC2 vCPU quotas.

The cluster configuration must use an EMR-supported instance type while remaining within the account's available EC2 quota.

---

## Cleanup

EMR clusters incur charges while running, including while the cluster is in the `WAITING` state.

To remove the project infrastructure:

```bash
cd terraform
terraform plan -destroy
```

Then:

```bash
terraform destroy
```

After destruction, verify that Terraform no longer tracks resources:

```bash
terraform state list
```

The project's S3 buckets use `force_destroy`, allowing Terraform to remove their project data during infrastructure cleanup.

---

## Key Concepts Demonstrated

This project demonstrates:

- Infrastructure as Code with Terraform
- Event-driven data ingestion
- S3 event notifications
- Lambda-based validation
- Step Functions orchestration
- EMR cluster provisioning
- Distributed processing with Apache Spark
- PySpark ETL
- CSV-to-Parquet conversion
- Partitioned data lake design
- Curated and gold data layers
- Business-level aggregation
- IAM service roles and `iam:PassRole`
- AWS networking for EMR
- Terraform state and infrastructure drift
- AWS service quotas
- Glue Data Catalog integration

---

## Future Improvements

Potential enhancements include:

- Athena queries over the gold dataset
- Direct Glue Catalog table registration
- Amazon QuickSight dashboards
- Incremental aggregation instead of rebuilding the full gold dataset
- Apache Iceberg or Delta Lake tables
- Data quality and reconciliation rules
- Quarantine handling for invalid records
- CloudWatch monitoring and alarms
- Private subnets and VPC endpoints
- EMR auto-termination
- EMR Serverless for intermittent workloads
- CI/CD with GitHub Actions
- Terraform remote state
- Automated integration tests

---

## Purpose

This project was built as a hands-on AWS Data Engineering implementation to demonstrate how multiple AWS services can be combined into a production-style ETL architecture.

The core pipeline successfully demonstrates:

```text
S3
→ Lambda
→ Step Functions
→ EMR
→ Spark / PySpark
→ Curated Parquet
→ Gold Parquet
```
