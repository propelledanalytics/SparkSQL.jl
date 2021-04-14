# createGlobalTempView Function
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
