local tinytoml = require("tinytoml")
local tested = require("tested")

tested.test("max nesting depth", function()
	local crazy_toml = {"e="}
	for i = 1, 2000 do
		table.insert(crazy_toml, "{e=")
	end

	table.insert(crazy_toml, "{}")
	for i = 1, 2000 do
		table.insert(crazy_toml, "}")
	end

	local ok, err = pcall(tinytoml.parse, table.concat(crazy_toml), {load_from_string=true})

	tested.assert({given="too much nesting", should="raies an error", expected=false, actual=ok})
	tested.assert({given="too much nesting", should="error includes max_nesting_depth", expected=true, actual=err:find("'max_nesting_depth'") ~= nil})

end)

tested.test("at max nesting depth", function()
	local crazy_toml = {"e="}
	for i = 1, 998 do
		table.insert(crazy_toml, "{e=")
	end

	table.insert(crazy_toml, "{}")
	for i = 1, 998 do
		table.insert(crazy_toml, "}")
	end

	local ok, err = pcall(tinytoml.parse, table.concat(crazy_toml), {load_from_string=true})

	tested.assert({given="edge of nesting", should="does not raise an error", expected=true, actual=ok})
end)

tested.test("slightly above max nesting depth", function()
	local crazy_toml = {"e="}
	for i = 1, 1500 do
		table.insert(crazy_toml, "{e=")
	end

	table.insert(crazy_toml, "{}")
	for i = 1, 1500 do
		table.insert(crazy_toml, "}")
	end

	local ok, err = pcall(tinytoml.parse, table.concat(crazy_toml), {load_from_string=true, max_nesting_depth=2000})

	tested.assert({given="edge of nesting", should="does not raise an error", expected=true, actual=ok})
end)

return tested
