local cjson = require("cjson")
local tinytoml = require("tinytoml")

local to_inf_and_beyound = {
   ["inf"] = true,
   ["-inf"] = true,
   ["nan"] = true,
   ["-nan"] = true,
}


local function float_to_string(x)


   if to_inf_and_beyound[tostring(x)] then
      return tostring(x)
   end
   for precision = 15, 17 do

      local s = ('%%.%dg'):format(precision):format(x)

      if tonumber(s) == x then
         return s
      end
   end
end


local assign_value_function = function(value, value_type)
   if value_type == "float" then
      return { ["value"] = float_to_string(value), ["type"] = value_type }
   else
      return { ["value"] = tostring(value), ["type"] = value_type }
   end
end

print(cjson.encode(tinytoml.parse(io.read("*a"), { load_from_string = true, assign_value_function = assign_value_function })))
