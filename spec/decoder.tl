#!/usr/bin/env lua

local cjson = require("cjson")
local tinytoml = require("tinytoml")

local to_inf_and_beyound = {
   ["inf"] = true,
   ["-inf"] = true,
   ["nan"] = true,
   ["-nan"] = true
}

-- Using a slightly modified version from https://stackoverflow.com/a/69827191
local function float_to_string(x: number): string
   -- a table key can't be nan in Lua, and I would've rather checked for equality with
   -- math.huge/nan (as 0/0), but (0/0) != (0/0) in Lua so I think this is probably fine.
   if to_inf_and_beyound[tostring(x)] then
      return tostring(x)
   end
   for precision = 15, 17 do
      -- Use a 2-layer format to try different precisions with %g.
      local s <const> = ('%%.%dg'):format(precision):format(x)
      -- See if s is an exact representation of x.
      if tonumber(s) == x then
         return s
      end
   end
end

-- the format toml-test expects
local assign_value_function = function(value: any, value_type?: string): any 
   if value_type == "float" then
      return {["value"]=float_to_string(value as number), ["type"]=value_type}
   else
      return {["value"]=tostring(value), ["type"]=value_type} 
   end
end

print(cjson.encode(tinytoml.parse(io.read("*a"), {load_from_string=true, assign_value_function=assign_value_function})))

