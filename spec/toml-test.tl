local cjson = require("cjson")
local tinytoml = require("tinytoml")

-- the format toml-test expects
local assign_value_function = function(value: any, value_type?: string): any 
    return {["value"]=tostring(value), ["type"]=value_type} 
end

print(cjson.encode(tinytoml.parse(io.read("*a"), {load_from_string=true, assign_value_function=assign_value_function})))

