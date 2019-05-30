# InfluxDB

A package that makes talking to an InfluxDB server a walk in the veritable park.

[![Build Status](https://travis-ci.org/staticfloat/InfluxDB.jl.svg?branch=master)](https://travis-ci.org/staticfloat/InfluxDB.jl)

# Example

```julia
using InfluxDB

addr = "http://localhost:8086"
server = InfluxDB.InfluxServer(addr)

# show available databases
db_names = InfluxDB.get_database_names(server)

# create a database
InfluxDB.create_db(server, "testDB1")

# write to a database
InfluxDB.write(server, "testDB1", "t1", Dict("temp"=>0.34) )

# read from a database
InfluxDB.query_series(server, "testDB1", "t1")
```