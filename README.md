# tinytoml
[![Run Tests and Code Coverage](https://github.com/FourierTransformer/tinytoml/actions/workflows/test-and-coverage.yml/badge.svg)](https://github.com/FourierTransformer/tinytoml/actions/workflows/test-and-coverage.yml) [![Coverage Status](https://coveralls.io/repos/github/FourierTransformer/tinytoml/badge.svg?branch=refs/pull/1/merge)](https://coveralls.io/github/FourierTransformer/tinytoml?branch=main)

tinytoml is a pure Lua [TOML](https://toml.io) parsing library. It's written in [Teal](https://github.com/teal-language/tl) and works with Lua 5.1-5.4 and LuaJIT 2.0/2.1. tinytoml parses a TOML document into a standard Lua table using default Lua types. Since TOML supports various datetime types, those are _defaultly_ represented by strings, but can be configured to use a custom type if desired.

tinytoml passes all the [toml-test](https://github.com/toml-lang/toml-test) use cases that Lua can realistically pass (even the UTF-8 ones!). The few that fail are mostly representational:
- Lua doesn't differentiate between an array or a dictionary, so tests involving _empty_ arrays fail.
- Some Lua versions have differences in how numbers are represented
- tinytoml currently support trailing commas in arrays/inline-tables. This is coming in TOML 1.1.0.

Current Supported TOML Version: 1.0.0

## Implemented and Missing Features
- TOML Parsing in Pure Lua, just grab the tinytoml.lua file and go!
- Does not keep track of comments
- Cannot encode a table to TOML

## Installing
You can grab the `tinytoml.lua` file from this repo (or the `tinytoml.tl` file if using Teal)

## Parsing TOML

### `tinytoml.parse(filename [, options])`
With no options, tinytoml will load the file and parse it directly into a Lua table.

```lua
local tinytoml = require("tinytoml")
tinytoml.parse("filename.toml")
```
It will throw an `error()` if unable to parse the file.

### Options
There are a few parsing options available that are passed in the the `options` parameter as a table.

- `load_from_string`

  allows loading the TOML data from a string rather than a file:
  ```lua
  tinytoml.parse("fruit='banana\'nvegetable='carrot'", {load_from_string=true})
  ```

- `type_conversion`

  allows registering a function to perform type conversions from the raw string to a custom representation. TOML requires them all the be RFC3339 compliant, and the strings are already verified when this function is called. The `type_conversion` option currently supports the various datetime types:
  - `datetime` - includes TZ (`2024-10-31T12:49:00Z`)
  - `datetime-local` - no TZ (`2024-10-31T12:49:00`)
  - `date-local` - Just the date (`2024-10-31`)
  - `time-local` - Just the time (`12:49:00`)

  For example, if you wanted to use [luatz](https://github.com/daurnimator/luatz) for handling datetimes:
  ```lua
  local luatz = require("luatz")
  local type_conversion = {
    ["datetime"] = luatz.parse.rfc_3339, -- realistically you would want to handle errors accordingly
    ["datetime-local"] = luatz.parse.rfc_3339
  }
  tinytoml.parse("a=2024-10-31T12:49:00Z", {load_from_string=true, type_conversion=type_conversion})
  ```

  or just use your own function:
  ```lua
  local function my_custom_datetime(raw_string)
    return {["now_in_a_table"] = raw_string}
  end
  local type_conversion = {
    ["datetime"] = my_custom_datetime,
    ["datetime-local"] = my_custom_datetime
  }
  tinytoml.parse("a=2024-10-31T12:49:00Z", {load_from_string=true, type_conversion=type_conversion})
  ```
- `assign_value_function`

  this method is called when assigning _every_ value to a table. It's mostly used to help perform the unit testing using [toml-test](https://github.com/toml-lang/toml-test), since they want to see the type and parsed value for comparison purposes. This option is the only one that has potential to change, so we advice against using it. If you need specific functionality that you're implementing through this (or find this function useful in general) - please let us know.
