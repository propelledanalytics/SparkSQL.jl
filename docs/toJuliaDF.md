# toJuliaDF Function
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
