import argparse

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    sum as spark_sum,
    count,
    countDistinct
)

parser = argparse.ArgumentParser()

parser.add_argument("--input-path", required=True)
parser.add_argument("--output-path", required=True)

args = parser.parse_args()

spark = (
    SparkSession.builder
    .appName("PremiumAggregation")
    .getOrCreate()
)

df = spark.read.parquet(args.input_path)

aggregated_df = (
    df
    .groupBy(
        "payment_date",
        "state",
        "product_type"
    )
    .agg(
        spark_sum("premium_amount").alias("total_premium"),
        count("premium_id").alias("premium_transactions"),
        countDistinct("policy_id").alias("unique_policies")
    )
)

(
    aggregated_df.write
    .mode("overwrite")
    .partitionBy("payment_date")
    .parquet(args.output_path)
)

spark.stop()