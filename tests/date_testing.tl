local tested = require("tested")
local tinytoml = require("tinytoml")

tested.test("encode date as string", function()

    local date_toml = [[offset_datetime = 1979-05-27T07:32:00Z
local_datetime = 1979-05-27T07:32:00
local_time = 07:32:00
local_date = 1979-05-27]]

    local expected = {
      offset_datetime = "1979-05-27T07:32:00Z",
      local_datetime = "1979-05-27T07:32:00",
      local_time = "07:32:00",
      local_date = "1979-05-27"
    }

    local parsed_dates = tinytoml.parse(date_toml, {load_from_string=true, parse_datetime_as="string"})

    tested.assert({given="toml with dates", should="parse dates as strings", expected=expected, actual=parsed_dates})

end)

tested.test("encode date as table", function()

    local date_toml = [[offset_datetime = 1979-05-27T07:32:00Z
local_datetime = 1979-05-27T07:32:00
local_time = 07:32:00
local_date = 1979-05-27]]

    local expected = {
      offset_datetime = {year = 1979, month = 05, day = 27, hour = 7, min = 32, sec = 0, msec = 0, time_offset = "00:00"},
      local_datetime = {year = 1979, month = 05, day = 27, hour = 7, min = 32, sec = 0, msec = 0},
      local_time = {hour = 7, min = 32, sec = 0, msec = 0},
      local_date = {year = 1979, month = 05, day = 27}
    }

    local parsed_dates = tinytoml.parse(date_toml, {load_from_string=true, parse_datetime_as="table"})

    tested.assert({given="toml with dates", should="parse dates as tables", expected=expected, actual=parsed_dates})

end)

return tested