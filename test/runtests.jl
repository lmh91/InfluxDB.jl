using InfluxDB
using Test

# using HTTP
# using JSON

# write your own tests here
#@test 1 == 1


addr = "http://localhost:8086"
server = InfluxDB.InfluxServer(addr)
db_names = InfluxDB.get_database_names(server)
@show db_names

InfluxDB.create_db(server, "testDB1")
db_names = InfluxDB.get_database_names(server)
@show db_names

InfluxDB.write(server, "testDB1", "t1", Dict("temp"=>0.34) )
