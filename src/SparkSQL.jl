"""
# Purpose
Submits *Structured Query Language* (SQL), *Data Manipulation Language* (DML) and *Data Definition Language* (DDL) statements to Apache Spark.
Has functions to move data from Spark into Julia DataFrames and Julia DataFrame data into Spark.

### Use Case
Apache Spark is one of the world's most popular open source big data processing engines. Spark supports programming in Java, Scala, Python, SQL, and R.
This package enables Julia programs to utilize Apache Spark for structured data processing using SQL.

The design goal of this package is to enable Julia centric programming using Apache Spark with just SQL.  There are only 8 functions. No need to use Java, Scala, Python or R.  Work with Spark data all from within Julia.
The SparkSQL.jl package uses the Dataset APIs internally giving Julia users the performance benefit of Spark's catalyst optimizer and tungsten engine. The earlier Spark RDD API is not supported.

This package is for structured and semi-structured data in Data Lakes, Lakehouses (Delta Lake) on premise and in the cloud.

# Available Functions
Use ? to see help for each function.
- `initJVM`: initializes the Java Virtual Machine (JVM) in Julia.
- `SparkSession`: submits application to Apache Spark cluster with config options.
- `sql`: function to submit SQL, DDL, and DML statements to Spark.
- `cache`: function to cache Spark Dataset into memory.
- `createOrReplaceTempView`: creates temporary view that lasts the duration of the session.
- `createGlobalTempView`: creates temporary view that lasts the duration of the application.
- `toJuliaDF`: move Spark data into a Julia DataFrame.
- `toSparkDS`: move Julia DataFrame data to a Spark Dataset.


# Quick Start
### Install and Setup
Download Apache Spark 3.2.0 or later and set the environmental variables for Spark and Java home:
```
export SPARK_HOME=/path/to/apache/spark
export JAVA_HOME=/path/to/java
```

### Usage
Start Julia with `"JULIA_COPY_STACKS=yes"` required for JVM interop:
```
JULIA_COPY_STACKS=yes julia
```
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
sqlQuery = sql(sparkSession, "SELECT split(value, ',' )[0] AS columnName1, split(value, ',' )[1] AS columnName2 FROM tempTable")
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
- Scalable metadata handling: Leverages Spark’s distributed processing power to handle all the metadata for petabyte-scale tables with billions of files at ease.

Example shows create table (DDL), insert (DML) and select (SQL) statements using Delta Lake and SparkSQL:
```
sql(session, "CREATE DATABASE demo;")
sql(session, "USE demo;")
sql(session, "CREATE TABLE tb(col STRING) USING DELTA;" )
```
The Delta Lake feature requires adding the Delta Lake jar to the Spark jars folder.

"""
module SparkSQL


using JavaCall
using DataFrames
using Decimals
using Dates
using ProgressMeter

export initJVM, SparkSession, sql, cache, createOrReplaceTempView, createGlobalTempView, toJuliaDF, toSparkDS


const SparkSession = @jimport org.apache.spark.sql.SparkSession
const SparkSessionBuilder = @jimport org.apache.spark.sql.SparkSession$Builder
const Dataset = @jimport org.apache.spark.sql.Dataset
const sparkDataFrame = @jimport org.apache.spark.sql.DataFrame
const GenericRow = @jimport org.apache.spark.sql.catalyst.expressions.GenericRowWithSchema
const Row = @jimport org.apache.spark.sql.Row
const DataTypes = @jimport org.apache.spark.sql.types.DataTypes
const StructType = @jimport org.apache.spark.sql.types.StructType
const StructField = @jimport org.apache.spark.sql.types.StructField
const ArrayList = @jimport java.util.ArrayList
const Encoder = @jimport org.apache.spark.sql.Encoder
const Encoders = @jimport org.apache.spark.sql.Encoders
const RowEncoder = @jimport org.apache.spark.sql.catalyst.encoders.RowEncoder
const RowFactory = @jimport org.apache.spark.sql.RowFactory
const ExpressionEncoder = @jimport org.apache.spark.sql.catalyst.encoders.ExpressionEncoder


jvmCast(juliaType) = juliaType
jvmCast(jvmType::JString) = unsafe_string(jvmType)
jvmCast(jvmType::JavaObject{Symbol("java.lang.Long")}) = jcall(jvmType, "longValue", jlong, ())
jvmCast(jvmType::JavaObject{Symbol("java.lang.Integer")}) = jcall(jvmType, "intValue", jint, ())
jvmCast(jvmType::JavaObject{Symbol("java.lang.Double")}) = jcall(jvmType, "doubleValue", jdouble, ())
jvmCast(jvmType::JavaObject{Symbol("java.lang.Float")}) = jcall(jvmType, "floatValue", jfloat, ())
jvmCast(jvmType::JavaObject{Symbol("java.lang.Boolean")}) = jcall(jvmType, "booleanValue", jboolean, ())
jvmCast(jvmType::JavaObject{Symbol("java.sql.Date")}) =  Dates.Date((jcall(jvmType, "toString", (JString), ())), dateformat"yyyy-mm-dd" )
jvmCast(jvmType::JavaObject{Symbol("java.sql.Timestamp")}) =  Dates.DateTime((jcall(jvmType, "toString", (JString), ())), dateformat"yyyy-mm-dd HH:MM:SS.sss")
jvmCast(jvmType::JavaObject{Symbol("org.apache.spark.sql.types.DecimalType")}) = Decimals.decimal((jcall(jvmType, "toString", (JString), ())))
jvmCast(jvmType::JavaObject{Symbol("java.math.BigDecimal")}) = parse(Decimal,(jcall(jvmType, "toString", (JString), ())) )


"""
# Purpose
Initializes the Java Virtual Machine (JVM) in Julia using the JavaCall package.

# Arguments
- leave blank to initialize the JVM without options.

# Examples
```
initJVM()
```
"""
function initJVM()
	SPARK_HOME = get(ENV,"SPARK_HOME","")
        if isempty(SPARK_HOME)
		print("JVM not initialized. Please set your SPARK_HOME ENV variable.")
        else
		for jar in readdir(joinpath(SPARK_HOME, "jars"))
			JavaCall.addClassPath(joinpath(SPARK_HOME,"jars", jar))
		end
		JavaCall.init()
        end
end


"""
# Purpose
Initializes the Java Virtual Machine (JVM) in Julia using the JavaCall package.

# Arguments
- `JVMOptions::String`: configuration options to pass to the JVM.

# Examples
```
initJVM("-XX:ParallelGCThreads=2")
```

"""
function initJVM(JVMOptions::String)
	SPARK_HOME = get(ENV,"SPARK_HOME","")
        if isempty(SPARK_HOME)
		print("JVM not initialized. Please set your SPARK_HOME ENV variable.")
        else
		for jar in readdir(joinpath(SPARK_HOME, "jars"))
			JavaCall.addClassPath(joinpath(SPARK_HOME,"jars", jar))
		end
		JavaCall.init(JVMOptions)
        end
end


"""
# Purpose
Submits application to Apache Spark cluster.

# Arguments
- `master::String`: the URL to the Spark cluster master.
- `appName::String`: the name of the application.


# Examples
Basic spark session:
```
spark = SparkSession("spark://example.com:7077", "Julia SparkSQL Example App")
```

"""
function SparkSession(master::String, appName::String)
	print("Starting Spark Session")
	builder = jcall(SparkSession,"builder", SparkSessionBuilder,())
	jcall(builder, "master", SparkSessionBuilder, (JString,), master)
	jcall(builder, "appName",SparkSessionBuilder, (JString,), appName)
	session = jcall(builder, "getOrCreate", SparkSession, ())
	return session::SparkSession
end


"""
# Purpose
Submits application to Apache Spark cluster with config options.

# Arguments
- `master::String`: the URL to the Spark cluster master.
- `appName::String`: the name of the application.
- `config::Dict{String, String}()`: one or more config option for the SparkSession.

# Examples
Basic spark session:
```
spark = SparkSession("spark://example.com:7077", "Julia SparkSQL Example App")
```

Spark Session with Hive config:
```
spark = SparkSession("spark://example.com:7077", "Julia SparkSQL Example App", Dict{String,String}("spark.sql.warehouse.dir"=>"LOCATION","spark.sql.catalogImplementation"=>"hive"))
```
Spark Session with Delta Lake config:
```
spark = SparkSession("spark://example.com:7077", "Julia SparkSQL Example App", Dict{String,String}("spark.sql.warehouse.dir"=>"LOCATION", "spark.sql.extensions"=>"io.delta.sql.DeltaSparkSessionExtension", "spark.sql.catalog.spark_catalog"=>"org.apache.spark.sql.delta.catalog.DeltaCatalog"))
```
"""
function SparkSession(master::String, appName::String, config=Dict{key::String, value::String}())
	print("Starting Spark Session")
	builder = jcall(SparkSession,"builder", SparkSessionBuilder,())
	jcall(builder, "master", SparkSessionBuilder, (JString,), master)
	jcall(builder, "appName",SparkSessionBuilder, (JString,), appName)

	for (key, value) in config
		jcall(builder, "config", SparkSessionBuilder, (JString, JString), key, value)
	end

	session = jcall(builder, "getOrCreate", SparkSession, ())
	return session::SparkSession
end


"""
# Purpose
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
"""
function sql(session::SparkSession, sqlText::String)
	ds = jcall(session, "sql", Dataset, (JString,), sqlText)
	return ds::Dataset
end


"""
# Purpose
Caches Spark Dataset into memory.

# Arguments
- `ds::Dataset`: Dataset to cache.

# Example
```
stmt = sql(session, "SELECT _c0 AS columnName1, _c1 AS columnName2 FROM CSV.`/pathToFile/fileName.csv`")
cache(stmt)
```
"""
function cache(ds::Dataset)
	dataset = jcall(ds, "cache", Dataset, ())
	return dataset::Dataset
end


"""
# Purpose
Creates a temporary database view on the Apache Spark Cluster for the duration of Spark session.
# Arguments
- `ds:Dataset`: the Spark Dataset to create a session database view.
- `tempViewName::String`: the name of the view.
# Example
```
stmt = sql(session, "SELECT * FROM CSV.`/pathToFile/fileName.csv`")
createOrReplaceTempView(stmt, "TempViewName")
count = sql(session, "SELECT COUNT(*) AS total FROM TempViewName;")
```
"""
function createOrReplaceTempView(ds::Dataset, tempViewName::String)
	jcall(ds, "createOrReplaceTempView", Nothing, (JString,), tempViewName)
end


"""
# Purpose
Creates a temporary database view on the Apache Spark cluster for the duration of the Spark application.
# Arguments
- `ds:Dataset`: the Spark DataSet to create a session database view.
- `tempViewName::String`: the name of the view.
# Examples
```
stmt = sql(session, "SELECT * FROM CSV.`/pathToFile/fileName.csv`")
createGlobalTempView(stmt, "TempViewName")
count = sql(session, "SELECT COUNT(*) AS total FROM TempViewName;")
```
"""
function createGlobalTempView(ds::Dataset, tempViewName::String)
	jcall(ds, "createGlobalTempView", Nothing, (JString,), tempViewName)
end


Base.length(row::GenericRow) = jcall(row, "length", jint, ())
Base.getindex(row::GenericRow, index::Integer) = jcall(row, "get", JObject, (jint,), index-1)


const toJuliaType = Dict{String, DataType}("StringType" => String, "DateType" => Date,
					"LongType" => Int64, "IntegerType" => Int32, "DoubleType" => Float64,
					"FloatType" => Float32, "BooleanType" => UInt8, "DecimalType" => Decimal,
					"TimestampType" => DateTime)


function decimalFormat(sparkType::String)
	if length(sparkType) < 7
		return sparkType
	end
	if SubString(sparkType, 1,7) == "Decimal"
		return "DecimalType"
	else
		return sparkType
	end
end


function createDataFrame(ds::Dataset)
	schema = jcall(ds, "dtypes", Array{JavaObject{Symbol("scala.Tuple2")},1}, ())
	columns = Symbol.(unsafe_string.(map(column_name -> convert(JString, jcall(column_name, "_1", JObject, ())), schema)))
	dataTypes = unsafe_string.(map(dtype -> convert(JString, jcall(dtype, "_2", JObject, ())), schema))
	juliaDataTypes = map(sparkType -> toJuliaType[decimalFormat(sparkType)], dataTypes)
	dataframe = DataFrame(columns .=> [type[] for type in juliaDataTypes])
	return dataframe::DataFrame
end

"""
# Purpose
Move Spark data into a new Julia DataFrame.

# Arguments
- `ds:Dataset`: the Apache Spark Dataset to import into Julia as a DataFrame.

# Data Types
The function supports the following data types when creating Julia DataFrames from Spark data:

- `String`
- `Date`
- `Timestamp`
- `integer`
- `long`
- `double`
- `float`
- `decimal`
- `boolean`

# Additional Requirements
You must include the DataFrames package in your Julia program.

`Using DataFrames`

Include the "Dates" and "Decimals" packages if your Spark data contains dates or decimal numbers.

`Using Dates, Decimals`

# Examples
```
stmt = sql(session, "SELECT _c0 AS columnName1, _c1 AS columnName2 FROM CSV.`/pathToFile/fileName.csv`")
createOrReplaceTempView(stmt, "TempViewName")
sqlQuery = sql(session, "SELECT columnName1, columnName2 FROM TempViewName;")
juliaDataFrame = toJuliaDF(sqlQuery)
```
"""
function toJuliaDF(ds::Dataset)

	dataframe = createDataFrame(ds)
	row = jcall(ds,"collectAsList", JavaObject{Symbol("java.util.List")},())
	showProgress = ProgressUnknown("Rows retrieved:")
        for record in JavaCall.iterator(row)
		push!(dataframe, [jvmCast(narrow(record[i])) for i in 1:length(record)])
		ProgressMeter.next!(showProgress)
	end
	ProgressMeter.finish!(showProgress)

    return dataframe::DataFrame
end


import JavaCall: iterator

"""
# Purpose
Moves Julia DataFrame data to a Dataset in Apache Spark.
# Arguments
- `session::SparkSession`: the Spark Session.
- `df::DataFrame`: the name of the Julia DataFrame to move into a Spark Dataset.

# Examples
The example demonstrates how to query Spark and move that data to a Julia dataFrame. Then, after processing in Julia, move data back into a Spark Dataset.

Spark into a Julia DataFrame:
```
stmt = sql(session, "SELECT _c0 AS columnName1, _c1 AS columnName2 FROM CSV.`/pathToFile/fileName.csv`")
createOrReplaceTempView(stmt, "TempViewName")
sqlQuery = sql(session, "SELECT columnName1, columnName2 FROM TempViewName;")
juliaDataFrame = toJuliaDF(sqlQuery)
describe(juliaDataFrame)
```
Move Julia DataFrame data into an Apache Spark Dataset.
```
sparkDataset = toSparkDS(sparkSession, juliaDataFrame)
createOrReplaceTempView(sparkDataset, "tempTable")
```
The Dataset is a delimited string. To generate columns use the SparkSQL "split" function.

```
sqlQuery = sql(sparkSession, "SELECT split(value, ',' )[0] AS columnName1, split(value, ',' )[1] AS columnName2 FROM tempTable")
```
"""
function toSparkDS(session::SparkSession, df::DataFrame)

	rows = ArrayList(())
	columnRange = 1:size(df)[2]
	showProgress = ProgressUnknown("Rows sent:")
	for record in eachrow(df)
		jcall(rows, "add", jboolean, (JObject,), join(map(i -> string(record[i]),  columnRange), ","))
		ProgressMeter.next!(showProgress)
	end

 	stringEncoder = jcall( JavaObject{Symbol("org.apache.spark.sql.Encoders")}, "STRING", JavaObject{Symbol("org.apache.spark.sql.Encoder")}, ())
	ds = jcall(session, "createDataset", Dataset, (JavaObject{Symbol("java.util.List")}, JavaObject{Symbol("org.apache.spark.sql.Encoder")}), rows, stringEncoder)
	ProgressMeter.finish!(showProgress)

	return ds::Dataset

end

"""
# Purpose
Moves Julia DataFrame data to a Dataset in Apache Spark.
# Arguments
- `session::SparkSession`: the Spark Session.
- `df::DataFrame`: the name of the Julia Dataframe to move into a Spark Dataset.
- `delimiter::String`: The delimiter to use.

# Examples
The example demonstrates how to query Spark and move that data to a Julia DataFrame. Then, after processing in Julia, move data back into a Spark Dataset.

Move data from Spark into a Julia DataFrame:
```
stmt = sql(session, "SELECT _c0 AS columnName1, _c1 AS columnName2 FROM CSV.`/pathToFile/fileName.csv`")
createOrReplaceTempView(stmt, "TempViewName")
sqlQuery = sql(session, "SELECT columnName1, columnName2 FROM TempViewName;")
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
sqlQuery = sql(sparkSession, "SELECT split(value, ',' )[0] AS columnName1, split(value, ',' )[1] AS columnName2 FROM tempTable")
```
"""
function toSparkDS(session::SparkSession, df::DataFrame, delimiter::String)

	rows = ArrayList(())
	columnRange = 1:size(df)[2]
	showProgress = ProgressUnknown("Rows sent:")
	for record in eachrow(df)
		jcall(rows, "add", jboolean, (JObject,), join(map(i -> string(record[i]),  columnRange), delimiter))
		ProgressMeter.next!(showProgress)
	end

 	stringEncoder = jcall( JavaObject{Symbol("org.apache.spark.sql.Encoders")}, "STRING", JavaObject{Symbol("org.apache.spark.sql.Encoder")}, ())
	ds = jcall(session, "createDataset", Dataset, (JavaObject{Symbol("java.util.List")}, JavaObject{Symbol("org.apache.spark.sql.Encoder")}), rows, stringEncoder)
	ProgressMeter.finish!(showProgress)

	return ds::Dataset

end


end # module
