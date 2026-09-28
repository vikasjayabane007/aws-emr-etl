import argparse

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col,
    current_timestamp,
    to_date
)


# ---------------------------------------------------------
# Read command-line arguments
# ---------------------------------------------------------

parser = argparse.ArgumentParser()

parser.add_argument("--input-bucket", required=True)
parser.add_argument("--input-key", required=True)
parser.add_argument("--output-path", required=True)

args = parser.parse_args()


input_path = f"s3://{args.input_bucket}/{args.input_key}"
output_path = args.output_path


# ---------------------------------------------------------
# Spark
# ---------------------------------------------------------

spark = (
    SparkSession.builder
    .appName("PremiumTransformation")
    .getOrCreate()
)


# ---------------------------------------------------------
# Read raw CSV
# ---------------------------------------------------------

df = (
    spark.read
    .option("header", "true")
    .option("inferSchema", "true")
    .csv(input_path)
)


# ---------------------------------------------------------
# Transform
# ---------------------------------------------------------

clean_df = (
    df
    .dropDuplicates(["premium_id"])

    .withColumn(
        "premium_amount",
        col("premium_amount").cast("decimal(18,2)")
    )

    .withColumn(
        "payment_date",
        to_date(col("payment_date"))
    )

    .filter(col("policy_id").isNotNull())
    .filter(col("premium_amount").isNotNull())
    .filter(col("payment_date").isNotNull())

    .withColumn(
        "processed_at",
        current_timestamp()
    )
)


# ---------------------------------------------------------
# Write curated data
# ---------------------------------------------------------

(
    clean_df.write
    .mode("append")
    .partitionBy("payment_date")
    .parquet(output_path)
)


spark.stop()