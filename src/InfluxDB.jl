__precompile__()
module InfluxDB

export InfluxServer, create_db, query
import Base: write

using JSON
using HTTP
using DataFrames
using Compat

using HTTP.URIs

# A server that we will be communicating with
struct InfluxServer
    # HTTP API endpoints
    addr::URI

    # Optional authentication stuffage
    username::Union{AbstractString, Nothing}
    password::Union{AbstractString, Nothing}

    # Build a server object that we can use in queries from now on
    function InfluxServer(address::AbstractString; username::Union{AbstractString, Nothing} = nothing, password::Union{AbstractString, Nothing} = nothing)
        # If there wasn't a schema defined (we only recognize http/https), default to http
        if !occursin(r"^https?://", address)
            uri = URI("http://$address")
        else
            uri = URI(address)
        end

        # If we didn't get an explicit port, default to 8086
        if uri.port == 0
            uri =  URI(uri.scheme, uri.host, 8086, uri.path)
        end

        # URIs are the new hotness
        return new(uri, username, password)
    end
end

# Add authentication to a query dict, if we need to
function authenticate!(server::InfluxServer, query::Dict)
    if !isnothing(server.username) && !isnothing(server.password)
        query["u"] = server.username
        query["p"] = server.password
    end
end


# Grab a timeseries
function query_series( server::InfluxServer, db::AbstractString, name::AbstractString;
                       chunk_size::Integer=10000)
    query = Dict("db"=>db, "q"=>"SELECT * from $name")

    authenticate!(server, query)
    # response = get("$(server.addr)query"; query=query)
    response = HTTP.get(joinpath(server.addr.uri, "query"), query=query)
    if response.status != 200
        error(bytestring(response.data))
    end

    # Grab result, turn it into a dataframe
    series_dict = JSON.parse(bytestring(response.data))["results"][1]["series"][1]
    df = DataFrame()
    for name_idx in 1:length(series_dict["columns"])
       df[symbol(series_dict["columns"][name_idx])] = [x[name_idx] for x in series_dict["values"]]
    end
    return df
end

# Show a databases
function get_database_names(server::InfluxServer)::Vector{String}
    query::Dict{String, String} = Dict("q"=>"SHOW DATABASES")
    authenticate!(server, query)
    response = HTTP.get(joinpath(server.addr.uri, "query"), query=query)
    if response.status != 200
        # error(bytestring(response.data))
        error("Response status = ", response.status)
    end
    response_dict::Dict = JSON.parse(String(response.body))
    n_databases::Int = length(response_dict["results"][1]["series"][1]["values"])
    String[ response_dict["results"][1]["series"][1]["values"][i][1] for i in 1:n_databases]
end
# Create a database!
function create_db(server::InfluxServer, db::AbstractString)
    query = Dict("q"=>"CREATE DATABASE \"$db\"")

    authenticate!(server, query)
    response = HTTP.get(joinpath(server.addr.uri, "query"), query=query)
    if response.status != 200
        error(bytestring(response.data))
    end
end

function write( server::InfluxServer, db::AbstractString, name::AbstractString, values::Dict;
                            tags=Dict{AbstractString,AbstractString}(), timestamp::Float64=time())
    if isempty(values)
        throw(ArgumentError("Must provide at least one value!"))
    end

    # Start by building our query dict, pointing at a particular database and timestamp precision
    query = Dict("db"=>db, "precision"=>"s")

    # Next, string of tags, if we have any
    tagstring = join([",$key=$val" for (key, val) in tags])

    # Next, our values
    valuestring = join(["$key=$val" for (key, val) in values], ",")

    # Finally, convert timestamp to seconds
    timestring = "$(round(Int64,timestamp))"

    # Put them all together to get a data string
    datastr = "$(name)$(tagstring) $(valuestring) $(timestring)"

    # Authenticate ourselves, if we need to
    authenticate!(server, query)
    response = HTTP.post(joinpath(server.addr.uri, "write"), query=query, data=datastr)
    if response.status != 204
        error(bytestring(response.data))
    end
end

end # module
