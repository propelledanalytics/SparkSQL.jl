# sql Function
Submits *Structured Query Language* (SQL), *Data Manipulation Language* (DML) and *Data Definition Language* (DDL) statements to Apache Spark.

# Arguments
- `session:SparkSession`: the SparkSession.  See SparkSession help for instructions on how to create in Julia.
- `sqlText::String`: the DDL, DML or SQL statements.

# DDL Supported formats:
- File formats including: CSV, JSON, arrow, parquet
- Data Lakes including: Hive, ORC, Avro
- Data Lake Houses: Delta Lake, Apache Iceberg.
- Cloud Object Stores: S3, Azure Blob Storage, Swift Object.

# Examples

## CSV file example:
Comma Separated Value (CSV) format.
```
stmt = sql(session, "SELECT * FROM CSV.`/pathToFile/fileName.csv`;")
```
## Parquet file example:
Apache Parquet format.
```
stmt = sql(session, "SELECT * FROM PARQUET.`/pathToFile/fileName.parquet`;")
```
## Delta Lake Example:
Delta Lake is an open-source storage layer for Spark. Delta Lake offers:

ACID transactions on Spark: Serializable isolation levels ensure that readers never see inconsistent data.
Scalable metadata handling: Leverages Spark’s distributed processing power to handle all the metadata for petabyte-scale tables with billions of files at ease.

To use Delta Lake you must add the Delta Lake jar to your Spark jars folder.

Example shows create table (DDL), insert (DML) and select statements (SQL) using Delta Lake and SparkSQL:
```
sql(session, "CREATE DATABASE demo;")
sql(session, "USE demo;")
sql(session, "CREATE TABLE tb(col STRING) USING DELTA;" )
```
