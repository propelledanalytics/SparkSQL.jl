# SparkSQL.jl
SparkSQL.jl is software that enables developers to use the Julia programming language with the Apache Spark data processing engine. 

### About
SparkSQL.jl provides the functionality that enables using Apache Spark and Julia together for tabular data. With SparkSQL.jl, Julia is the most advanced software tooling for data science and machine learning work on Spark.

Apache Spark is one of the world’s most ubiquitous open-source big data processing engines. Spark’s distributed processing power enables it to process very large datasets. Apache Spark runs on many platforms and hardware architectures including those used by large enterprise and government.

Released in 2012, Julia is a modern programming language ideally suited for data science and machine learning workloads. Expertly designed, Julia is a highly performant language. It sports multiple-dispatch, auto-differentiation and a rich ecosystem of packages.

### Use Case
Submits *Structured Query Language* (SQL), *Data Manipulation Language* (DML) and *Data Definition Language* (DDL) statements to Apache Spark.
Has functions to move data from Spark into Julia DataFrames and Julia DataFrame data into Spark. 

SparkSQL.jl delivers advanced features like dynamic horizontal autoscaling that scale compute nodes to match workload requirements. 

This package supports structured and semi-structured data in Data Lakes, Lakehouses (Delta Lake, Iceberg) on premise and in the cloud.


# Available Functions
Use ? in the Julia REPL to see help for each function.
- `initJVM`: initializes the Java Virtual Machine (JVM) in Julia. [Help file.](docs/initJVM.md)
- `SparkSession`: submits application to Apache Spark cluster with config options. [Help file.](docs/sparksession.md)
- `sql`: function to submit SQL, DDL, and DML statements to Spark. [Help file.](docs/sql.md)
- `cache`: function to cache Spark Dataset into memory. [Help file.](docs/cache.md)
- `createOrReplaceTempView`: creates temporary view that lasts the duration of the session. [Help file.](docs/createOrReplaceTempView.md)
- `createGlobalTempView`: creates temporary view that lasts the duration of the application. [Help file.](docs/createGlobalTempView.md)
- `toJuliaDF`: move Spark data into a Julia DataFrame. [Help file.](docs/toJuliaDF.md)
- `toSparkDS`: move Julia DataFrame data to a Spark Dataset. [Help file.](docs/toSparkDS.md)

The SparkSQL.jl compute node autoscaling feature is based on Kubernetes. For SparkSQL.jl on Kubernetes instructions see:
[SparkSQL.jl kubernetes readme](kubernetes/README.md)

# Quick Start
### Install and Setup
Download Apache Spark 3.2.0 or later and set the environmental variables for Spark and Java home:
```
export SPARK_HOME=/path/to/apache/spark
export JAVA_HOME=/path/to/java
```
If using OpenJDK 11 on Linux set processReaperUseDefaultStackSize to true:
```
export _JAVA_OPTIONS='-Djdk.lang.processReaperUseDefaultStackSize=true'
```

### Startup

Start Julia with `"JULIA_COPY_STACKS=yes"` required for JVM interop:
```
JULIA_COPY_STACKS=yes julia
```
On MacOS start Julia with "handle-signals=no":
```
JULIA_COPY_STACKS=yes julia --handle-signals=no
```
### Usage

In Julia include the DataFrames package.  Also include the Dates and Decimals packages if your Spark data contains dates or decimal numbers.
```
using SparkSQL, DataFrames, Dates, Decimals
```
Initialize the JVM and start the Spark Session:
```
initJVM()
sparkSession = SparkSession("spark://example.com:7077", "Julia SparkSQL Example App")
```
Query data from Spark and load it into a Julia Dataset.
```
stmt = sql(sparkSession, "SELECT _c0 AS columnName1, _c1 AS columnName2 FROM CSV.`/pathToFile/fileName.csv`")
createOrReplaceTempView(stmt, "TempViewName")
sqlQuery = sql(sparkSession, "SELECT columnName1, columnName2 FROM TempViewName;")
juliaDataFrame = toJuliaDF(sqlQuery)
describe(juliaDataFrame)
```
Move Julia DataFrame data into an Apache Spark Dataset.
```
sparkDataset = toSparkDS(sparkSession, juliaDataFrame,",")
createOrReplaceTempView(sparkDataset, "tempTable")
```
The Dataset is a delimited string. To generate columns use the SparkSQL "split" function.

```
sqlQuery = sql(sparkSession, "Select split(value, ',' )[0] AS columnName1, split(value, ',' )[1] AS columnName2 from tempTable")
```

# Spark Data Sources
Supported data-sources include:
- File formats including: CSV, JSON, arrow, parquet
- Data Lakes including: Hive, ORC, Avro
- Data Lake Houses: Delta Lake, Apache Iceberg.
- Cloud Object Stores: S3, Azure Blob Storage, Swift Object.

## Data Source Examples

### CSV file example:
Comma Separated Value (CSV) format.
```
stmt = sql(session, "SELECT * FROM CSV.`/pathToFile/fileName.csv`;")
```
### Parquet file example:
Apache Parquet format.
```
stmt = sql(session, "SELECT * FROM PARQUET.`/pathToFile/fileName.parquet`;")
```
### Delta Lake Example:
Delta Lake is an open-source storage layer for Spark. Delta Lake offers:

- ACID transactions on Spark: Serializable isolation levels ensure that readers never see inconsistent data.
- Scalable metadata handling: Leverages Spark’s distributed processing power to handle all the metadata for petabyte-scale tables with billions of files.

Example shows create table (DDL) statements using Delta Lake and SparkSQL:
```
sql(session, "CREATE DATABASE demo;")
sql(session, "USE demo;")
sql(session, "CREATE TABLE tb(col STRING) USING DELTA;" )
```
The Delta Lake feature requires adding the Delta Lake jar to the Spark jars folder.
