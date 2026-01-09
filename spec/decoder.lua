

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


local function add_toml_test_tag(table_to_clear)
   if type(table_to_clear) ~= "table" then

      if type(table_to_clear) == "number" then
         if math.type(table_to_clear) == "integer" then
            return {type="integer", value=tostring(table_to_clear)}
         else
            return {type="float", value=float_to_string(table_to_clear)}
         end

      elseif type(table_to_clear) == "string" then
         return {type="string", value=table_to_clear}

      elseif type(table_to_clear) == "boolean" then
         return {type="bool", value=tostring(table_to_clear)}

      else
         return table_to_clear["value"]
      end

   else
      for k, v in pairs(table_to_clear) do
         table_to_clear[k] = add_toml_test_tag(v)
      end
   end

   return table_to_clear
end

local output = tinytoml.parse(io.read("*a"), { load_from_string = true, encode_date_and_times_as = "table" })
add_toml_test_tag(output)
print(cjson.encode(output))
