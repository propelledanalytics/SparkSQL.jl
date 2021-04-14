# toSparkDS Function
Moves Julia DataFrame data to a Dataset in Apache Spark.
# Arguments
- `session::SparkSession`: the Spark Session.
- `df::DataFrame`: the name of the Julia Dataframe to move into a Spark Dataset.
- `delimiter::String`: The delimiter to use. (optional) the default delimiter is ",".

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
sqlQuery = sql(sparkSession, "Select split(value, ',' )[0] AS columnName1, split(value, ',' )[1] AS columnName2 from tempTable")
```
