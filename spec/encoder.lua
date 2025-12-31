#!/usr/bin/env lua

local cjson = require("cjson")
local tinytoml = require("tinytoml")

local exploded_json = cjson.decode(io.read("*a"))

local exact_floats = {
    ["+inf"] = math.huge,
    ["inf"] = math.huge,
    ["-inf"] = -math.huge,
    ["+nan"] = (0/0),
    ["nan"] = (0/0),
    ["-nan"] = (-(0/0)),
}

local function clear_toml_test_tag(table_to_clear)
	if table_to_clear["type"] ~= nil and table_to_clear["value"] ~= nil then
		
		if table_to_clear["type"] == "integer" then
			return tonumber(table_to_clear["value"])
		
		elseif table_to_clear["type"] == "float" then
			if exact_floats[table_to_clear["value"]] then
				return exact_floats[table_to_clear["value"]]
			else
				return tonumber(table_to_clear["value"])
			end
		
		elseif table_to_clear["type"] == "bool" then
			return table_to_clear["value"] == "true"
		
		else
			return table_to_clear["value"]
		end
	
	else
		for k, v in pairs(table_to_clear) do
			table_to_clear[k] = clear_toml_test_tag(v)
		end
	end

	return table_to_clear
end

clear_toml_test_tag(exploded_json)

print(tinytoml.encode(exploded_json))
