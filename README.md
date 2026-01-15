# tinytoml
[![Run Tests and Code Coverage](https://github.com/FourierTransformer/tinytoml/actions/workflows/test-and-coverage.yml/badge.svg)](https://github.com/FourierTransformer/tinytoml/actions/workflows/test-and-coverage.yml) [![Coverage Status](https://coveralls.io/repos/github/FourierTransformer/tinytoml/badge.svg?branch=refs/pull/1/merge)](https://coveralls.io/github/FourierTransformer/tinytoml?branch=main)

tinytoml is a pure Lua [TOML](https://toml.io) parsing library. It's written in [Teal](https://github.com/teal-language/tl) and works with Lua 5.1-5.5 and LuaJIT 2.0/2.1. tinytoml parses a TOML document into a standard Lua table using default Lua types. Since TOML supports various datetime types, those are by default represented by strings, but can be configured as a table or passed in to a method so it is represented by a custom or 3rd-party library.

tinytoml passes all the [toml-test](https://github.com/toml-lang/toml-test) use cases that Lua can realistically pass (even the UTF-8 ones!). The few that fail are mostly representational:
- Lua doesn't differentiate between an array or a dictionary, so tests involving _empty_ arrays fail.
- Some Lua versions have differences in how numbers are represented. Lua 5.3 introduced integers, so tests involving integer representation pass on Lua 5.3+

Current Supported TOML Version: 1.1.0

> [!TIP]
> | [Installing](#installing) | [Parsing](#parsing-toml) | [Encoding](#encoding-toml) | [Comparison](#comparison) |
> | ---------- | ------- | -------- | ---------- |

## Installing
You can grab the `tinytoml.lua` file from this repo (or the `tinytoml.tl` file if using Teal) or install it via LuaRocks

```
luarocks install tinytoml
```

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

- `load_from_string` (defaults to `false`)

  allows loading the TOML data from a string rather than a file:
  ```lua
  tinytoml.parse("fruit='banana'\nvegetable='carrot'", {load_from_string=true})
  ```

- `type_conversion`

  allows registering a function to perform type conversions from the raw string to a custom representation. TOML requires them all the be RFC3339 compliant, and the strings are already verified when this function is called. The `type_conversion` option currently supports the various datetime types:
  - `datetime` - includes TZ (`2024-10-31T12:49:00Z` or `2024-10-31T19:49:00+07:00`)
  - `datetime-local` - no TZ (`2024-10-31T12:49:00`), cannot pinpoint to a specific instant in time
  - `date-local` - Just the date (`2024-10-31`)
  - `time-local` - Just the time (`12:49:00`)

  For example, if you wanted to use [date](https://github.com/Tieske/date) for handling datetime:
  ```lua
  local date = require("date")
  local type_conversion = {
    ["datetime"] = date,
    ["datetime-local"] = date, --date will assume UTC
    ["date-local"] = date,
    ["time-local"] = date,
  }
  tinytoml.parse("a=2024-10-31T12:49:00Z", {load_from_string=true, type_conversion=type_conversion})
  ```
  or using your own function:
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

- `parse_datetime_as` (default `string`)

  Allows encoding datetime either as a `string` or a `table`. The `table` will take all the individual fields and place them in a table.
  This can be used in conjunction with `type_conversion` - either the string or table representation would be passed into whatever function is
  specified in `type_conversion`.

  Example:

  ```toml
  offset_datetime = 1979-05-27T07:32:00Z
  local_datetime = 1979-05-27T07:32:00
  local_time = 07:32:00
  local_date = 1979-05-27
  ```

  ```lua
  -- with the option: { parse_datetime_as = "string" }
  {
    offset_datetime = "1979-05-27T07:32:00Z",
    local_datetime = "1979-05-27T07:32:00",
    local_time = "07:32:00",
    local_date = "1979-05-27"
  }

  -- with the option: { parse_datetime_as = "table" }
  {
    offset_datetime = {year = 1979, month = 05, day = 27, hour = 7, min = 32, sec = 0, msec = 0, time_offset = "00:00"},
    local_datetime = {year = 1979, month = 05, day = 27, hour = 7, min = 32, sec = 0, msec = 0},
    local_time = {hour = 7, min = 32, sec = 0, msec = 0},
    local_date = {year = 1979, month = 05, day = 27}
  }

  ```

- `max_nesting_depth` (default `1000`) and `max_filesize` (default `100000000` - 100 MB)

  The maximum nesting depth and maxmimum filesize in bytes. tinytoml will throw an error if either of these are exceeded.


## Encoding TOML

tinytoml includes a basic TOML encoder, since we don't preserve comments (and have no plans to), this library is not good for _editing_ hand-written TOML files. If you want to do that, the [toml-edit library](https://github.com/lumen-oss/toml-edit.lua) is a much better choice. However, there may be situations where you need a pure Lua TOML encoder, and tinytoml could prove useful.

### ```tinytoml.encode(table, [, options])```
Takes in a Lua table and encodes it as a TOML string. TOML [requires](https://toml.io/en/v1.1.0#preliminaries) files to be UTF-8 encoded, and the tinytoml encoder will enforce that the output is UTF-8.

### Options

- `allow_multiline_strings` (defaults to `false`)

  will place strings that have newlines (either `\n` or `\r\n`) in TOML multi-line strings (surrounded by `"""`) instead of escaping the newlines.

  ```lua
  tinytoml.encode({test = "Hello\nThis will print on the second line"}, {allow_multiline_strings = true})
  ```

  Which will generate:
  ```toml
  test = """Hello
  This will print on the second line"""
  ```

### On encoding dates and times
Since Lua doesn't have a builtin date or time type, we can't just do a `type` on an object to get its type and write it out correctly. To remedy this, we check if a Lua string _looks_ and validates as a date or time and then write it out as one of the TOML datetime types ([offset date-time](https://toml.io/en/v1.1.0#offset-date-time), [local date-time](https://toml.io/en/v1.1.0#local-date-time), [local date](https://toml.io/en/v1.1.0#local-date), or [local time](https://toml.io/en/v1.1.0#local-time)).

Example:
```lua
{
  offset_datetime = "1979-05-27T07:32:00Z",
  local_datetime = "1979-05-27T07:32:00",
  local_date = "1979-05-27",
  local_time = "07:32:00",
}
```

Would then encode to
```toml
offset_datetime = 1979-05-27T07:32:00Z
local_datetime = 1979-05-27T07:32:00
local_time = 07:32:00
local_date = 1979-05-27
```

This effectively means you'll have to pre-process dates and times to strings in your codebase, before passing them to tinytoml's encoder.

## Comparison
Here's a helpful comparison table that can be useful in deciding which Lua TOML parser to use. The data was collected with the most recent versions as of 1/2026.

| Feature / Library | tinytoml                      | toml-edit                     | toml.lua                      | toml2lua                       | tomlua                        |
|:------------------|:------------------------------|:------------------------------|:------------------------------|:-------------------------------|:------------------------------|
| Language          | Lua                           | Rust binding                  | C++ binding                   | Lua                            | C                             |
| TOML Version      | 1.1.0                         | 1.0.0                         | 1.0.0                         | 1.0.0                          | Not Specified                 |
| UTF-8 Support     | ✅                             | ✅                             | ✅                             | ✅                              | ✅                             |
| Passes toml-test  | ✅                             | ✅                             | ✅                             | ❌                              | ❌                             |
| Date/Time Support | String/Table/Register Method  |                               | Custom Userdata/Lua Table     | Lua Table                      | Custom Userdata               |
| Encoder           | Basic                         | Comment Preserving            | Basic, many options           | Basic                          | Very Configurable             |
| 16 KB TOML decode | Lua: 3.9ms <br> LuaJIT: 2.7ms | Lua: 2.8ms <br> LuaJIT: 1.0ms | Lua: dnf <br> LuaJIT: 2.4ms   | Lua: 32.5ms <br> LuaJIT: 7.0ms | Lua: 1.6ms <br> LuaJIT: .29ms |
| 8 MB TOML decode  | Lua: 1.49s <br> LuaJIT: 415ms  | Lua: 929ms <br> LuaJIT: 462ms | Lua: error <br> LuaJIT: error | Lua: 12.01s <br> LuaJIT: 3.13s  | Lua: 318ms <br> LuaJIT: 119.7ms     |

**NOTES:**
- tinytoml, toml2lua, and tomlua's toml-test support were verified by running through toml-test. toml-edit and toml.lua were based on the bindings, which both passed toml-test.
- I was using hyperfine to run the tests, and toml.lua's time estimate rapidly started rising in the middle of the 16KB run and segfaulted with the higher runs.
- Tests were run in a docker container running on an arm64 Mac, as tomlua did not compile on macOS at the time the benchmarks were taken.
- Standard benchmark disclaimer: These are all relative to each other and your mileage will [likely] vary.
