local cjson = require("cjson")
local tinytoml = require("tinytoml")


local assign_value_function = function(value, value_type)
   return { ["value"] = tostring(value), ["type"] = value_type }
end

print(cjson.encode(tinytoml.parse(io.read("*a"), { load_from_string = true, assign_value_function = assign_value_function })))
