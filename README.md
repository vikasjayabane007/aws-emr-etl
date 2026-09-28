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
-
