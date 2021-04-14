# cache Function

Caches Spark Dataset into memory.

# Arguments
- `ds::Dataset`: Dataset to cache.

# Example
```
stmt = sql(session, "SELECT _c0 AS columnName1, _c1 AS columnName2 FROM CSV.`/pathToFile/fileName.csv`")
cache(stmt)
```
