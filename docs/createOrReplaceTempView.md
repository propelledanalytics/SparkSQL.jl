# createOrReplaceTempView Function
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
