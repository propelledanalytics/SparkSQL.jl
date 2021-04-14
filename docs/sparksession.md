# SparkSession Function
Submits application to Apache Spark cluster with config options.

# Arguments
- `master::String`: the URL to the Spark cluster master.
- `appName::String`: the name of the application.
- `config::Dict{String, String}()`: one or more config option for the SparkSession. (optional).

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
