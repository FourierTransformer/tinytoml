local enum TomlConversionType
    "datetime-local"
    "datetime"
    "date-local"
    "time-local"
end

local enum DateTimeEncode
    "string"
    "table"
end

local record TinyTomlOptions
    load_from_string: boolean
    type_conversion: {TomlConversionType:function<T>(raw_value: string | table):T}
    encode_date_and_times_as: DateTimeEncode
    max_filesize: integer
    max_nesting_depth: integer
end

local record tinytoml
    parse: function(filename: string, options?: TinyTomlOptions): {string: any}
    _VERSION: string
    _TOML_VERSION: string
    _DESCRIPTION: string
    _URL: string
    _LICENSE: string
end

local TOML_VERSION = "1.1.0"
tinytoml._VERSION = "tinytoml 1.0.0"
tinytoml._TOML_VERSION = TOML_VERSION
tinytoml._DESCRIPTION = "a single-file pure Lua TOML parser"
tinytoml._URL = "https://github.com/FourierTransformer/tinytoml"
tinytoml._LICENSE = "MIT"

local enum TomlType
    -- my types (users should not interact with these)
    "array"
    "inline-table"
    "string"
    "integer"
    "float"
    "bool"
    "datetime"
    "datetime-local"
    "date-local"
    "time-local"
end

local enum TableType
    "table"
    "arrays_of_tables"
end

local enum MetaType
    "auto-dictionary"
    "dictionary"
    "array"
    "value"
    "value-dictionary" -- not overridable from table
end

local enum states
    "start_of_line"
    "key"
    "inside_key"
    "table"
    "inside_table"
    "assign"
    "value"
    "array"
    "inside_array"
    "inline_table"
    "inside_inline_table"
    "error"
    "wait_for_key"
    "wait_for_newline"
    "?" -- function decides next state
end

local enum TOML_anchors
    "objectives"
    "preliminaries"
    "comment"
    "keyvalue-pair"
    "keys"
    "string"
    "integer"
    "float"
    "boolean"
    "offset-date-time"
    "local-date-time"
    "local-date"
    "local-time"
    "array"
    "table"
    "inline-table"
    "array-of-tables"
    "filename-extension"
    "mime-type"
    "abnf-grammar"
end

local record MTType
    type: MetaType
end

local record InlineTableSave
    previous_state: states
    current_table: {any}
    meta_table: {any:{MTType}}
    keys: {string}
end

-- i feel like this really grew into quite a large table. 
-- Not entirely sure how to feel about it now, but maybe I'll consider what refactoring looks like later.
local record StateMachine
    -- variables for processing the input
    options: TinyTomlOptions
    input_length: integer
    input: string
    i: integer

    -- variables you can reuse to save allocation time
    _: integer -- any optionals
    ext: string -- second capture from string.find
    match: string -- first capture from string.find
    byte: integer -- value from string.byte
    end_seq: integer -- get end of sequence from string.find

    -- variables for output/setting, update only when sure of value
    multiline_string: boolean
    table_type: TableType
    value_type: TomlType
    tables: {string} -- for dotted table names
    arrays: {{any}} -- for handling inline arrays
    nested_arrays: integer -- keep track of nested arrays
    nested_inline_tables: integer
    keys: {string}
    value: any

    -- added for conveinence
    mode: states -- needed to determine where inline tables can output
    line_number: integer -- current processed line, used in error messages
    line_number_char_index: integer -- string index of the latest newline
    filename: string -- used in error message

    -- final output and current table pointer
    output: {string:any}
    current_table: {any}
    meta_table: {any:{MTType}}
    current_meta_table: {any:{MTType}}
    inline_table_backup: {InlineTableSave} -- stores all the stuff as we descend into nested inline-tables
end

local sbyte = string.byte
local chars: {string:integer} = {
    SINGLE_QUOTE = sbyte("'"),
    DOUBLE_QUOTE = sbyte('"'),
    OPEN_BRACKET = sbyte("["),
    CLOSE_BRACKET = sbyte("]"),
    BACKSLASH = sbyte("\\"),
    COMMA = sbyte(","),
    POUND = sbyte("#"),
    DOT = sbyte("."),
    CR = sbyte("\r"),
    LF = sbyte("\n")
}


local function replace_control_chars(s: string): string, integer
    return string.gsub(s, "[%z\x01-\x08\x0b-\x1f\x7f]", function(c: string): string
        return string.format("\\x%02x", string.byte(c))
    end)
end

local function _error(sm: StateMachine, message: string, anchor?: TOML_anchors)
    local error_message = {}

    -- small hack to allow the error messages to work in encoder.
    -- sm.filename is not present for the encoder, so we can't really display line info.
    if sm.filename then
        error_message = {"\n\nIn '", sm.filename, "', line ", sm.line_number, ":\n\n  "}

        local _, end_line = sm.input:find(".-\n", sm.line_number_char_index)
        error_message[#error_message + 1] = sm.line_number
        error_message[#error_message + 1] = " | "
        error_message[#error_message + 1] = replace_control_chars(sm.input:sub(sm.line_number_char_index, end_line))
        error_message[#error_message + 1] = (end_line and "\n" or "\n\n")
    end

    error_message[#error_message + 1] = message
    error_message[#error_message + 1] = "\n"

    if anchor ~= nil then
        error_message[#error_message + 1] = "\nSee https://toml.io/en/v"
        error_message[#error_message + 1] = TOML_VERSION
        error_message[#error_message + 1] = "#"
        error_message[#error_message + 1] = anchor
        error_message[#error_message + 1] = " for more details"
    end

    error(table.concat(error_message))
end

global unpack: function
local _unpack = unpack or table.unpack
local _tointeger = math.tointeger or tonumber as function(string): integer
-- function from https://stackoverflow.com/a/26237757
local _utf8char = utf8 and utf8.char or function(cp: number): string
    if cp < 128 then
      return string.char(cp as integer)
    end
    local suffix = cp % 64
    local c4 = 128 + suffix
    cp = (cp - suffix) / 64
    if cp < 32 then
      return string.char(192 + (cp as integer), (c4 as integer))
    end
    suffix = cp % 64
    local c3 = 128 + suffix
    cp = (cp - suffix) / 64
    if cp < 16 then
      return string.char(224 + (cp as integer), c3 as integer, c4 as integer)
    end
    suffix = cp % 64
    cp = (cp - suffix) / 64
    return string.char(240 + (cp as integer), 128 + (suffix as integer), c3 as integer, c4 as integer)
end

local function validate_utf8(input: string, toml_sub?: boolean): boolean, integer, integer, string
    local i, len, line_number, line_number_start = 1, #input, 1, 1
    local byte, second, third, fourth: integer, integer, integer, integer = 0, 129, 129, 129
    toml_sub = toml_sub or false
    while i <= len do
        byte = sbyte(input, i)

        if byte <= 127 then
            if toml_sub then
                if byte < 9 then return false, line_number, line_number_start, "TOML only allows some control characters, but they must be escaped in double quoted strings"
                elseif byte == chars.CR and sbyte(input, i+1) ~= chars.LF then return false, line_number, line_number_start, "TOML requires all '\\r' be followed by '\\n'"
                elseif byte == chars.LF then
                    line_number = line_number + 1
                    line_number_start = i + 1
                elseif byte >= 11 and byte <= 31 and byte ~= 13 then return false, line_number, line_number_start, "TOML only allows some control characters, but they must be escaped in double quoted strings"
                elseif byte == 127 then return false, line_number, line_number_start, "TOML only allows some control characters, but they must be escaped in double quoted strings" end
            end
            i = i + 1

        elseif byte >= 194 and byte <= 223 then
            second = sbyte(input, i+1)
            i = i + 2

        elseif byte == 224 then
            second = sbyte(input, i+1); third = sbyte(input, i+2)
            -- overlong
            if second ~= nil and  second >= 128 and second <= 159 then return false, line_number, line_number_start, "Invalid UTF-8 Sequence" end
            i = i + 3

        elseif byte == 237 then
            second = sbyte(input, i+1); third = sbyte(input, i+2)
            -- surrogate
            if second ~= nil and second >= 160 and second <= 191 then return false, line_number, line_number_start, "Invalid UTF-8 Sequence" end
            i = i + 3

        elseif (byte >= 225 and byte <= 236) or byte == 238 or byte == 239 then
            second = sbyte(input, i+1); third = sbyte(input, i+2)
            i = i + 3

        elseif byte == 240 then
            second = sbyte(input, i+1); third = sbyte(input, i+2); fourth = sbyte(input, i+3)
            -- overlong
            if second ~= nil and second >= 128 and second <= 143 then return false, line_number, line_number_start, "Invalid UTF-8 Sequence" end
            i = i + 4

        elseif byte == 241 or byte == 242 or byte == 243 then
            second = sbyte(input, i+1); third = sbyte(input, i+2); fourth = sbyte(input, i+3)
            i = i + 4

        elseif byte == 244 then
            second = sbyte(input, i+1); third = sbyte(input, i+2); fourth = sbyte(input, i+3)
            -- exceeds max utf-8
            if second ~= nil and second >= 160 and second <= 191 then return false, line_number, line_number_start, "Invalid UTF-8 Sequence" end
            i = i + 4

        else
            -- can't go this high
            return false, line_number, line_number_start, "Invalid UTF-8 Sequence"
        end

        -- unfinished (nil) or invalid (not in range)
        if second == nil or second < 128 or second > 191 then return false, line_number, line_number_start, "Invalid UTF-8 Sequence" end
        if third == nil or third < 128 or third > 191 then return false, line_number, line_number_start, "Invalid UTF-8 Sequence" end
        if fourth == nil or fourth < 128 or fourth > 191 then return false, line_number, line_number_start, "Invalid UTF-8 Sequence" end

    end
    return true
end

local function find_newline(sm: StateMachine)
    sm._, sm.end_seq = sm.input:find("\r?\n", sm.i)
    -- likely at end of script
    if sm.end_seq == nil then
        sm._, sm.end_seq = sm.input:find(".-$", sm.i)
    end
    sm.line_number = sm.line_number + 1
    sm.i = sm.end_seq + 1
    sm.line_number_char_index = sm.i
end

local escape_sequences: {string:string} = {
    ['b'] = '\b',
    ['t'] = '\t',
    ['n'] = '\n',
    ['f'] = '\f',
    ['r'] = '\r',
    ['e'] = '\x1B',
    ['\\'] = '\\',
    ['"'] = '"',
}

-- returns string to insert, boolean to indicate if quote_count to reset
local function handle_backslash_escape(sm: StateMachine): string, boolean

    -- the multiline special "line ending backslash"
    if sm.multiline_string then
        if sm.input:find("^\\[ \t]-\r?\n", sm.i) then
            sm._, sm.end_seq = sm.input:find("%S", sm.i+1)
            sm.i = sm.end_seq - 1
            return "", false
        end
    end

    -- basic escape sequences
    sm._, sm.end_seq, sm.match = sm.input:find('^([\\btrfne"])', sm.i+1)
    local escape = escape_sequences[sm.match]
    if escape then
        sm.i = sm.end_seq
        if sm.match == '"' then
            return escape, true
        else
            return escape, false
        end
    end

    -- hex escape sequences
    sm._, sm.end_seq, sm.match, sm.ext = sm.input:find("^(x)([0-9a-fA-F][0-9a-fA-F])", sm.i+1) as (integer, integer, string, string)
    if sm.match then
        local codepoint_to_insert = _utf8char(tonumber(sm.ext, 16))
        if not validate_utf8(codepoint_to_insert) then
            _error(sm, "Escaped UTF-8 sequence not valid UTF-8 character: '\\" .. sm.match .. sm.ext .. "'", "string")
        end
        sm.i = sm.end_seq
        return codepoint_to_insert, false
    end

    -- unicode escape sequences
    sm._, sm.end_seq, sm.match, sm.ext = sm.input:find("^(u)([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])", sm.i+1) as (integer, integer, string, string)
    if not sm.match then
        sm._, sm.end_seq, sm.match, sm.ext = sm.input:find("^(U)([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])", sm.i+1) as (integer, integer, string, string)
    end
    if sm.match then
        local codepoint_to_insert = _utf8char(tonumber(sm.ext, 16))
        if not validate_utf8(codepoint_to_insert) then
            _error(sm, "Escaped UTF-8 sequence not valid UTF-8 character: '\\" .. sm.match .. sm.ext .. "'", "string")
        end
        sm.i = sm.end_seq
        return codepoint_to_insert, false
    end

    return nil
end

local function close_string(sm: StateMachine)
    local escape: string
    local reset_quote: boolean
    local start_field, end_field = sm.i + 1, 0
    local second, third = sbyte(sm.input, sm.i+1), sbyte(sm.input, sm.i+2)
    local quote_count = 0
    local output = {} -- will add sequences here then concat at the end
    local found_closing_quote = false
    sm.multiline_string = false

    -- check for multiline and setup accordingly
    if second == chars.DOUBLE_QUOTE and third == chars.DOUBLE_QUOTE then
        if sm.mode == "table" then _error(sm, "Cannot have multiline strings as table keys", "table") end
        sm.multiline_string = true
        start_field = sm.i + 3
        -- toml allows a newline at the beginning of a triple quote
        second, third = sbyte(sm.input, sm.i+3), sbyte(sm.input, sm.i+4)
        if second == chars.LF then
            start_field = start_field + 1
        elseif second == chars.CR and third == chars.LF then
            start_field = start_field + 2
        end
        sm.i = start_field - 1
    end

    while found_closing_quote == false and sm.i <= sm.input_length do
        sm.i = sm.i + 1
        sm.byte = sbyte(sm.input, sm.i)
        if sm.byte == chars.BACKSLASH then
            output[#output+1] = sm.input:sub(start_field, sm.i-1)

            escape, reset_quote = handle_backslash_escape(sm)
            if reset_quote then quote_count = 0 end

            if escape ~= nil then
                output[#output+1] = escape
            else
                sm._, sm._, sm.match = sm.input:find("(.-[^'\"])", sm.i+1)
                _error(sm, "TOML only allows specific escape sequences. Invalid escape sequence found: '\\" .. sm.match .. "'", "string")
            end

            start_field = sm.i + 1

        elseif sm.multiline_string then
            if sm.byte == chars.DOUBLE_QUOTE then
                quote_count = quote_count + 1
                if quote_count == 5 then
                    end_field = sm.i-3
                    output[#output+1] = sm.input:sub(start_field, end_field)
                    found_closing_quote = true
                    break
                end
            else
                if quote_count >= 3 then
                    end_field = sm.i-4
                    output[#output+1] = sm.input:sub(start_field, end_field)
                    found_closing_quote = true
                    sm.i = sm.i - 1
                    break
                else
                    quote_count = 0
                end
            end

        else
            if sm.byte == chars.DOUBLE_QUOTE then
                end_field = sm.i-1
                output[#output+1] = sm.input:sub(start_field, end_field)
                found_closing_quote = true
                break
            elseif sm.byte == chars.CR or sm.byte == chars.LF then
                _error(sm, "String does not appear to be closed. Use multi-line (triple quoted) strings if non-escaped newlines are desired.", "string")
            end
        end
    end

    if not found_closing_quote then
        if sm.multiline_string then
            _error(sm, "Unable to find closing triple-quotes for multi-line string", "string")
        else
            _error(sm, "Unable to find closing quote for string", "string")
        end
    end

    sm.i = sm.i + 1
    sm.value = table.concat(output)
    sm.value_type = "string"
end

local function close_literal_string(sm: StateMachine)
    sm.byte = 0
    local start_field, end_field = sm.i+1, 0
    local second, third = sbyte(sm.input, sm.i+1), sbyte(sm.input, sm.i+2)
    local quote_count = 0
    sm.multiline_string = false

    -- check for multiline and setup accordingly
    if second == chars.SINGLE_QUOTE and third == chars.SINGLE_QUOTE then
        if sm.mode == "table" then _error(sm, "Cannot have multiline strings as table keys", "table") end
        sm.multiline_string = true
        start_field = sm.i + 3
        -- toml allows a newline at the beginning of a triple quote
        second, third = sbyte(sm.input, sm.i+3), sbyte(sm.input, sm.i+4)
        if second == chars.LF then
            start_field = start_field + 1
        elseif second == chars.CR and third == chars.LF then
            start_field = start_field + 2
        end
        sm.i = start_field
    end

    while end_field ~= 0 or sm.i <= sm.input_length do
        sm.i = sm.i + 1
        sm.byte = sbyte(sm.input, sm.i)
        if sm.multiline_string then
            if sm.byte == chars.SINGLE_QUOTE then
                quote_count = quote_count + 1
                if quote_count == 5 then
                    end_field = sm.i-3
                    break
                end
            else
                if quote_count >= 3 then
                    end_field = sm.i-4
                    sm.i = sm.i - 1
                    break
                else
                    quote_count = 0
                end
            end

        else
            if sm.byte == chars.SINGLE_QUOTE then
                end_field = sm.i-1
                break
            elseif sm.byte == chars.CR or sm.byte == chars.LF then
                _error(sm, "String does not appear to be closed. Use multi-line (triple quoted) strings if non-escaped newlines are desired.", "string")
            end
        end
    end

    if end_field == 0 then
        if sm.multiline_string then
            _error(sm, "Unable to find closing triple quotes for multi-line literal string", "string")
        else
            _error(sm, "Unable to find closing quote for literal string", "string")
        end
    end

    sm.i = sm.i + 1
    sm.value = sm.input:sub(start_field, end_field)
    sm.value_type = "string"
end

local function close_bare_string(sm: StateMachine)
    sm._, sm.end_seq, sm.match = sm.input:find("^([a-zA-Z0-9-_]+)", sm.i)
    if sm.match then
        sm.i = sm.end_seq + 1
        sm.multiline_string = false
        sm.value = sm.match
        sm.value_type = "string"
    else
        _error(sm, "Bare keys can only contain 'a-zA-Z0-9-_'. Invalid bare key found: '" .. sm.input:sub(sm.input:find("[^ #\r\n,]+", sm.i)) .. "'", "keys")
    end
end

-- sm is only passed in for error handling...
local function remove_underscores_number(sm:StateMachine, number: string, anchor: TOML_anchors): string
    if number:find("_") then
        if number:find("__") then _error(sm, "Numbers cannot have consecutive underscores. Found ".. anchor ..": '" .. number .. "'", anchor) end
        if number:find("^_") or number:find("_$") then _error(sm, "Underscores are not allowed at beginning or end of a number. Found " .. anchor ..": '" .. number .. "'", anchor) end
        if number:find("%D_%d") or number:find("%d_%D") then _error(sm, "Underscores must have digits on either side. Found " .. anchor ..": '" .. number .. "'", anchor) end
        number = number:gsub("_", "")
    end
    return number
end

local integer_match: {string:{string, integer}} = {
    ["b"] = {"^0b([01_]+)$", 2},
    ["o"] = {"^0o([0-7_]+)$", 8},
    ["x"] = {"^0x([0-9a-fA-F_]+)$", 16},
}

local function validate_integer(sm: StateMachine, value: string): boolean
    sm._, sm._, sm.match = value:find("^([-+]?[%d_]+)$")
    if sm.match then
        if sm.match:find("^[-+]?0[%d_]") then _error(sm, "Integers can't start with a leading 0. Found integer: '" .. sm.match .. "'", "integer") end
        sm.match = remove_underscores_number(sm, sm.match, "integer")
        sm.value = _tointeger(sm.match)
        sm.value_type = "integer"
        return true
    end

    if value:find("^0[box]") then
        local pattern_bits = integer_match[value:sub(2, 2)]
        sm._, sm._, sm.match = value:find(pattern_bits[1])
        if sm.match then
            sm.match = remove_underscores_number(sm, sm.match, "integer")
            sm.value = tonumber(sm.match, pattern_bits[2])
            sm.value_type = "integer"
            return true
        end
    end
end

local function validate_float(sm: StateMachine, value: string): boolean
    sm._, sm._, sm.match, sm.ext = value:find("^([-+]?[%d_]+%.[%d_]+)(.*)$") as (integer, integer, string, string)
    if sm.match then
        if sm.match:find("%._") or sm.match:find("_%.") then _error(sm, "Underscores in floats must have a number on either side. Found float: '" .. sm.match .. sm.ext .. "'", "float") end
        if sm.match:find("^[-+]?0[%d_]") then _error(sm, "Floats can't start with a leading 0. Found float: '" .. sm.match .. sm.ext .. "'", "float") end
        sm.match = remove_underscores_number(sm, sm.match, "float")
        if sm.ext ~= "" then
            if sm.ext:find("^[eE][-+]?[%d_]+$") then
                sm.ext = remove_underscores_number(sm, sm.ext, "float")
                sm.value = tonumber(sm.match..sm.ext)
                sm.value_type = "float"
                return true
            end
        else
            sm.value = tonumber(sm.match)
            sm.value_type = "float"
            return true
        end
    end

    sm._, sm._, sm.match = value:find("^([-+]?[%d_]+[eE][-+]?[%d_]+)$")
    if sm.match then
        if sm.match:find("_[eE]") or sm.match:find("[eE]_") then _error(sm, "Underscores in floats cannot be before or after the e. Found float: '" .. sm.match .. sm.ext .. "'", "float") end
        sm.match = remove_underscores_number(sm, sm.match, "float")
        sm.value = tonumber(sm.match)
        sm.value_type = "float"
        return true
    end
end

local max_days_in_month = {31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
local function validate_seconds(sm: StateMachine, sec: integer, anchor: TOML_anchors)
    if sec > 60 then _error(sm, "Seconds must be less than 61. Found second: " .. sec .. " in: '" .. sm.match .. "'", anchor) end
end

local function validate_hours_minutes(sm: StateMachine, hour: integer, min: integer, anchor: TOML_anchors)
    if hour > 23 then _error(sm, "Hours must be less than 24. Found hour: " .. hour .. " in: '" .. sm.match .. "'", anchor) end
    if min > 59 then _error(sm, "Minutes must be less than 60. Found minute: " .. min .. " in: '" .. sm.match .. "'", anchor) end
end

local function validate_month_date(sm: StateMachine, year: integer, month: integer, day: integer, anchor: TOML_anchors)
    if month == 0 or month > 12 then _error(sm, "Month must be between 01-12. Found month: " .. month .. " in: '" .. sm.match .. "'", anchor) end
    if day == 0 or day > max_days_in_month[month] then
        local months = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
        _error(sm, "Too many days in the month. Found " .. day .. " days in " .. months[month] .. ", which only has " .. max_days_in_month[month as integer] .. " days in: '" .. sm.match .. "'", anchor)
    end
    if month == 2 then
        local leap_year = (year % 4 == 0) and not(year % 100 == 0) or (year % 400 == 0)
        if leap_year == false then
            if day > 28 then _error(sm, "Too many days in month. Found " .. day .. " days in February, which only has 28 days if it's not a leap year in: '" .. sm.match .. "'", anchor) end
        end
    end
end

local function assign_time_local(sm: StateMachine, match: string, hour: integer, min: integer, sec: integer, msec: integer)
    sm.value_type = "time-local"
    if sm.options.encode_date_and_times_as == "string" then
        sm.value = sm.options.type_conversion[sm.value_type as TomlConversionType](match)
    else
        sm.value = sm.options.type_conversion[sm.value_type as TomlConversionType]({hour=hour, min=min, sec=sec, msec=msec})
    end
end

local function assign_date_local(sm: StateMachine, match: string, year: integer, month: integer, day: integer)
    sm.value_type = "date-local"
    if sm.options.encode_date_and_times_as == "string" then
        sm.value = sm.options.type_conversion[sm.value_type as TomlConversionType](match)
    else
        sm.value = sm.options.type_conversion[sm.value_type as TomlConversionType]({year=year, month=month, day=day})
    end
end

local function assign_datetime_local(sm: StateMachine, match: string, year: integer, month: integer, day: integer, hour: integer, min: integer, sec: integer, msec?: integer)
    sm.value_type = "datetime-local"
    if sm.options.encode_date_and_times_as == "string" then
        sm.value = sm.options.type_conversion[sm.value_type as TomlConversionType](match)
    else
        sm.value = sm.options.type_conversion[sm.value_type as TomlConversionType]({year=year, month=month, day=day, hour=hour, min=min, sec=sec, msec=msec or 0})
    end
end

local function assign_datetime(sm: StateMachine, match: string, year: integer, month: integer, day: integer, hour: integer, min: integer, sec: integer, msec?: integer)
    sm.value_type = "datetime"
    if sm.options.encode_date_and_times_as == "string" then
        sm.value = sm.options.type_conversion[sm.value_type as TomlConversionType](match)
    else
        sm.value = sm.options.type_conversion[sm.value_type as TomlConversionType]({year=year, month=month, day=day, hour=hour, min=min, sec=sec, msec=msec or 0})
    end
end

local function validate_datetime(sm: StateMachine, value: string): boolean
    local hour_s, min_s, sec_s, msec_s: string, string, string, string
    local hour, min, sec: integer, integer, integer
    sm._, sm._, sm.match, hour_s, min_s, sm.ext = value:find("^((%d%d):(%d%d))(.*)$") as (integer, integer, string, string, string, string)
    if sm.match then
        hour = _tointeger(hour_s)
        min = _tointeger(min_s)
        validate_hours_minutes(sm, hour, min, "local-time")
    
        if sm.ext ~= "" then
            sm._, sm._, sec_s = sm.ext:find("^:(%d%d)$")
            if sec_s then
                sec = _tointeger(sec_s)
                validate_seconds(sm, sec, "local-time")
                assign_time_local(sm, sm.match .. sm.ext, hour, min, sec, 0)
                return true
            end

            sm._, sm._, sec_s, msec_s = sm.ext:find("^:(%d%d)%.(%d+)$")
            if sec_s then
                sec = _tointeger(sec_s)
                validate_seconds(sm, sec, "local-time")
                assign_time_local(sm, sm.match .. sm.ext, hour, min, sec, _tointeger(msec_s))
                return true
            end
        else
            assign_time_local(sm, sm.match .. ":00", hour, min, 0, 0) -- assume :00 if no seconds are provided
            return true
        end
    end

    local year_s, month_s, day_s: string, string, string
    local year, month, day: integer, integer, integer
    sm._, sm._, sm.match, year_s, month_s, day_s = value:find("^((%d%d%d%d)%-(%d%d)%-(%d%d))$") as (integer, integer, string, string, string, string)
    if sm.match then
        year, month, day = _tointeger(year_s), _tointeger(month_s), _tointeger(day_s)
        validate_month_date(sm, year, month, day, "local-date")
        assign_date_local(sm, sm.match, year, month, day)

        -- small hack that allows datetimes with spaces to work
        -- does involve updating the current position in a validator...
        local potential_end_seq: integer

        -- yes, this find is little quick and greedy, but even if we match and
        -- it's not a real datetime, we'll generate an error message
        if sm.input:find("^ %d", sm.i) then
            sm._, potential_end_seq, sm.match = sm.input:find("^ ([%S]+)", sm.i)
            value = value .. " " .. sm.match
            sm.end_seq = potential_end_seq
            sm.i = sm.end_seq + 1
        else
            return true
        end
    end

    sm._, sm._, sm.match, year_s, month_s, day_s, hour_s, min_s, sm.ext =
        value:find("^((%d%d%d%d)%-(%d%d)%-(%d%d)[Tt ](%d%d):(%d%d))(.*)$")
        as (integer, integer, string, string, string, string, string, string, string)
    if sm.match then
        hour = _tointeger(hour_s)
        min = _tointeger(min_s)
        validate_hours_minutes(sm, hour, min, "local-time")
        year, month, day = _tointeger(year_s), _tointeger(month_s), _tointeger(day_s)
        validate_month_date(sm, year, month, day, "local-date-time")

        -- see if seconds are next
        local temp_ext: string
        sm._, sm._, sec_s, temp_ext = sm.ext:find("^:(%d%d)(.*)$") as (integer, integer, string, string)
        if sec_s then
            validate_seconds(sm, _tointeger(sec_s), "local-time")
            sm.match = sm.match .. ":" .. sec_s
            sm.ext = temp_ext
        else
            sm.match = sm.match .. ":00"
        end


        if sm.ext ~= "" then
            sm.match = sm.match .. sm.ext
            if sm.ext:find("^%.%d+$") then
                sm._, sm._, msec_s = sm.ext:find("^%.(%d+)Z$")
                assign_datetime_local(sm, sm.match, year, month, day, hour, min, sec, _tointeger(msec_s))
                return true
            elseif sm.ext:find("^%.%d+Z$") then
                sm._, sm._, msec_s = sm.ext:find("^%.(%d+)Z$")
                assign_datetime(sm, sm.match, year, month, day, hour, min, sec, _tointeger(msec_s))                
                return true
            elseif sm.ext:find("^%.%d+[+-]%d%d:%d%d$") then
                sm._, sm._, hour_s, min_s = sm.ext:find("^%.%d+[+-](%d%d):(%d%d)$") as (integer, integer, string, string)
                validate_hours_minutes(sm, _tointeger(hour_s), _tointeger(min_s), "offset-date-time")
                sm.value_type = "datetime"
                sm.value = sm.options.type_conversion[sm.value_type as TomlConversionType](sm.match)
                return true
            elseif sm.ext:find("^[Zz]$") then
                assign_datetime(sm, sm.match, year, month, day, hour, min, sec)
                return true
            elseif sm.ext:find("^[+-]%d%d:%d%d$") then
                sm._, sm._, hour_s, min_s = sm.ext:find("^[+-](%d%d):(%d%d)$") as (integer, integer, string, string)
                validate_hours_minutes(sm, _tointeger(hour_s), _tointeger(min_s), "offset-date-time")
                sm.value_type = "datetime"
                sm.value = sm.options.type_conversion[sm.value_type as TomlConversionType](sm.match)
                return true
            end
        else
            assign_datetime_local(sm, sm.match, year, month, day, hour, min, sec)
            -- sm.value_type = "datetime-local"
            -- sm.value = sm.options.type_conversion[sm.value_type as TomlConversionType](sm.match)
            return true
        end
    end
end

local validators: {function<T>(sm:StateMachine, value:string): boolean} = {
    validate_integer,
    validate_float,
    validate_datetime
}

local exact_matches: {string:{any, TomlType}} = {
    ["true"]= {true, "bool"},
    ["false"]= {false, "bool"},
    ["+inf"]= {math.huge, "float"},
    ["inf"]= {math.huge, "float"},
    ["-inf"]= {-math.huge, "float"},
    ["+nan"]= {(0/0), "float"},
    ["nan"]= {(0/0), "float"},
    ["-nan"]= {(-(0/0)), "float"},
}

local function close_other_value(sm: StateMachine)
    local successful_type: boolean
    sm._, sm.end_seq, sm.match = sm.input:find("^([^ #\r\n,%[{%]}]+)", sm.i)
    if sm.match == nil then
        _error(sm, "Key has been assigned, but value doesn't seem to exist", "keyvalue-pair")
    end
    sm.i = sm.end_seq + 1

    local value = sm.match
    local exact_value = exact_matches[value]
    if exact_value ~= nil then
        sm.value = exact_value[1]
        sm.value_type = exact_value[2]
        return
    end

    for _, validator in ipairs(validators) do
        successful_type = validator(sm, value)
        if successful_type == true then
            return
        end
    end

    _error(sm, "Unable to determine type of value for: '" .. value .. "'", "keyvalue-pair")
end

local function create_array(sm: StateMachine)
    sm.nested_arrays = sm.nested_arrays + 1
    if sm.nested_arrays >= sm.options.max_nesting_depth then
        _error(sm, "Maximum nesting depth has exceeded " .. sm.options.max_nesting_depth .. ". If this larger nesting depth is required, feel free to set 'max_nesting_depth' in the parser options.")
    end
    sm.arrays[sm.nested_arrays] = {}
    sm.i = sm.i + 1
end

local function add_array_comma(sm: StateMachine)
    table.insert(sm.arrays[sm.nested_arrays], sm.value)
    sm.value = nil -- to handle the post comma condition

    sm.i = sm.i + 1
end

local function close_array(sm: StateMachine): states
    -- the trailing comma will set it to nil, so we can skip assigning here
    if sm.value ~= nil then
        add_array_comma(sm)
    else
        sm.i = sm.i + 1
    end
    sm.value = sm.arrays[sm.nested_arrays]
    sm.value_type = "array"
    sm.nested_arrays = sm.nested_arrays - 1
    if sm.nested_arrays == 0 then
        return "assign"
    else
        return "inside_array"
    end
end

local function create_table(sm: StateMachine)
    sm.tables = {}
    sm.byte = sbyte(sm.input, sm.i+1)
    -- two [[, so arrays of tables instead
    if sm.byte == chars.OPEN_BRACKET then
        sm.i = sm.i + 2
        sm.table_type = "arrays_of_tables"
    else
        sm.i = sm.i + 1
        sm.table_type = "table"
    end
end

local function add_table_dot(sm: StateMachine)
    sm.tables[#sm.tables + 1] = sm.value as string
    sm.i = sm.i + 1
end

local function close_table(sm: StateMachine)
    sm.byte = sbyte(sm.input, sm.i+1)

    if sm.table_type == "arrays_of_tables" and sm.byte ~= chars.CLOSE_BRACKET then
        _error(sm, "Arrays of Tables should be closed with ']]'", "array-of-tables")
    end

    if sm.byte == chars.CLOSE_BRACKET then
        sm.i = sm.i + 2
    else
        sm.i = sm.i + 1
    end

    sm.tables[#sm.tables + 1] = sm.value as string

    local out_table: {any:{any}} = sm.output as {any:{any}}
    local meta_out_table: {any:{MTType}} = sm.meta_table as {any:{MTType}}

    for i = 1, #sm.tables-1 do
        if out_table[sm.tables[i]] == nil then
            -- create table in chain if it doesn't exist
            out_table[sm.tables[i]] = {}
            out_table = out_table[sm.tables[i]] as {any:{any}}

            meta_out_table[sm.tables[i]] = {type="auto-dictionary"} as {MTType}
            meta_out_table = meta_out_table[sm.tables[i]] as {any:{MTType}}
        else
            if (meta_out_table[sm.tables[i]] as MTType).type == "value" then
                _error(sm, "Cannot override previously definied value '" .. sm.tables[i] .. "' with new table definition: '" .. table.concat(sm.tables, ".") .. "'")
            end
            -- see if the next table is an array
            local next_table = out_table[sm.tables[i]][#out_table[sm.tables[i]]] as {any:{any}}
            local next_meta_table = meta_out_table[sm.tables[i]][#meta_out_table[sm.tables[i]]] as {any:{MTType}}
            -- if it is, insert into the current element
            if next_table == nil then
                out_table = out_table[sm.tables[i]] as {any:{any}}
                meta_out_table = meta_out_table[sm.tables[i]] as {any:{MTType}}
            else
                out_table = next_table
                meta_out_table = next_meta_table
            end
        end
    end
    local final_table = sm.tables[#sm.tables]

    if sm.table_type == "table" then
        if out_table[final_table] == nil then
            out_table[final_table] = {}
            meta_out_table[final_table] = {type="dictionary"} as {MTType}
        elseif (meta_out_table[final_table] as MTType).type == "value" then
            _error(sm, "Cannot override existing value '" .. sm.value as string .. "' with new table")
        elseif (meta_out_table[final_table] as MTType).type == "dictionary" then
            _error(sm, "Cannot override existing table '" .. sm.value as string .. "' with new table")
        elseif (meta_out_table[final_table] as MTType).type == "array" then
            _error(sm, "Cannot override existing array '" .. sm.value as string .. "' with new table")
        elseif (meta_out_table[final_table] as MTType).type == "value-dictionary" then
            _error(sm, "Cannot override existing value '" .. sm.value as string .. "' with new table")
        end
        (meta_out_table[final_table] as MTType).type = "dictionary"
        sm.current_table = out_table[final_table]
        sm.current_meta_table = meta_out_table[final_table] as {any: {MTType}}

    elseif sm.table_type == "arrays_of_tables" then
        if out_table[final_table] == nil then
            out_table[final_table] = {}
            meta_out_table[final_table] = {type="array"} as {MTType}
        elseif (meta_out_table[final_table] as MTType).type == "value" then
            _error(sm, "Cannot override existing value '" .. sm.value as string .. "' with new table")
        elseif (meta_out_table[final_table] as MTType).type == "dictionary" then
            _error(sm, "Cannot override existing table '" .. sm.value as string .. "' with new table")
        elseif (meta_out_table[final_table] as MTType).type == "auto-dictionary" then
            _error(sm, "Cannot override existing table '" .. sm.value as string .. "' with new table")
        elseif (meta_out_table[final_table] as MTType).type == "value-dictionary" then
            _error(sm, "Cannot override existing value '" .. sm.value as string .. "' with new table")
        end
        table.insert(out_table[final_table], {})
        table.insert(meta_out_table[final_table], {type="dictionary"})
        sm.current_table = out_table[final_table][#out_table[final_table]] as {any}
        sm.current_meta_table = meta_out_table[final_table][#meta_out_table[final_table]] as {any:{MTType}}
    end

end

local function assign_key(sm: StateMachine)
    if sm.multiline_string == false then
        sm.keys[#sm.keys + 1] = sm.value as string
    else
        _error(sm, "Cannot have multi-line string as keys. Found key: '" .. tostring(sm.value) .. "'", "keys")
    end

    -- cleared so the value doesn't get reused during empty table/array assignments
    sm.value = nil
    sm.value_type = nil

    sm.i = sm.i + 1
end

local function assign_value(sm: StateMachine)
    local output = {}
    output = sm.value as {any}

    -- iterate over keys, updating the pointer at "out_table"
    local out_table = sm.current_table as {any:any}
    local meta_out_table = sm.current_meta_table as {any:any}
    for i = 1, #sm.keys-1 do
        if out_table[sm.keys[i]] == nil then
            out_table[sm.keys[i]] = {}
            meta_out_table[sm.keys[i]] = {type="value-dictionary"}
        elseif (meta_out_table[sm.keys[i]] as MTType).type == "value" then
            _error(sm, "Cannot override existing value '" .. sm.keys[i] .."' in '" .. table.concat(sm.keys, ".") .. "'")
        elseif (meta_out_table[sm.keys[i]] as MTType).type == "dictionary" then
            _error(sm, "Cannot override existing table '" .. sm.keys[i] .."' in '" .. table.concat(sm.keys, ".") .. "'")
        elseif (meta_out_table[sm.keys[i]] as MTType).type == "array" then
            _error(sm, "Cannot override existing array '" .. sm.keys[i] .."' in '" .. table.concat(sm.keys, ".") .. "'")
        end
        out_table = out_table[sm.keys[i]] as {string:any}
        meta_out_table = meta_out_table[sm.keys[i]] as {any:{MTType}}
    end

    -- pointer to the last table in the sequence.
    local last_table = sm.keys[#sm.keys]

    if out_table[last_table] ~= nil then
        _error(sm, "Cannot override previously defined key '" .. sm.keys[#sm.keys] .. "'")
    end

    out_table[last_table] = output
    meta_out_table[last_table] = {type="value"}

    sm.keys = {}
    sm.value = nil
end

local function error_invalid_state(sm: StateMachine)
    local error_message = "Incorrectly formatted TOML. "
    local found = sm.input:sub(sm.i, sm.i); if found == "\r" or found == "\n" then found = "newline character" end
    if sm.mode == "start_of_line" then error_message = error_message .. "At start of line, could not find a key. Found '='"
    elseif sm.mode == "inside_table" then error_message = error_message .. "In a table definition, expected a '.' or ']'. Found: '" .. found .. "'"
    elseif sm.mode == "inside_key" then error_message = error_message .. "In a key defintion, expected a '.' or '='. Found: '" .. found .. "'"
    elseif sm.mode == "value" then error_message = error_message .. "Unspecified value, key was specified, but no value provided."
    elseif sm.mode == "inside_array" then error_message = error_message .. "Inside an array, expected a ']', '}' (if inside inline table), ',', newline, or comment. Found: " .. found
    elseif sm.mode == "wait_for_newline" then error_message = error_message .. "Just assigned value or created table. Expected newline or comment before continuing."
    end
    _error(sm, error_message)
end

local function create_inline_table(sm: StateMachine)
    sm.nested_inline_tables = sm.nested_inline_tables + 1

    if sm.nested_inline_tables >= sm.options.max_nesting_depth then
        _error(sm, "Maximum nesting depth has exceeded " .. sm.options.max_nesting_depth .. ". If this larger nesting depth is required, feel free to set 'max_nesting_depth' in the parser options.")
    end

    local backup: InlineTableSave = {
        previous_state = sm.mode,
        meta_table = sm.meta_table,
        current_table = sm.current_table as {any},
        keys = {_unpack(sm.keys)} as {string},
    }

    local new_inline_table = {}
    sm.current_table = new_inline_table

    sm.inline_table_backup[sm.nested_inline_tables] = backup

    sm.current_table = {}
    sm.meta_table = {}
    sm.keys = {}

    sm.i = sm.i + 1
end

local function close_inline_table(sm: StateMachine): states
    if sm.value ~= nil then
        assign_value(sm)
    end
    sm.i = sm.i + 1
    sm.value = sm.current_table
    sm.value_type = "inline-table"

    local restore = sm.inline_table_backup[sm.nested_inline_tables]
    sm.keys = restore.keys
    sm.meta_table = restore.meta_table
    sm.current_table = restore.current_table as {any}

    sm.nested_inline_tables = sm.nested_inline_tables - 1

    if restore.previous_state == "array" then
        return "inside_array"
    elseif restore.previous_state == "value" then
        return "assign"
    else
        _error(sm, "close_inline_table should not be called from the previous state: " .. restore.previous_state as string .. ". Please submit an issue with your TOML file so we can look into the issue!")
    end
end

local function skip_comma(sm: StateMachine)
    sm.i = sm.i + 1
end

local transitions: {states:{integer:{function, states}}} = {
    ["start_of_line"] = {
        [sbyte("#")] = {find_newline, "start_of_line"},
        [sbyte("\r")] = {find_newline, "start_of_line"},
        [sbyte("\n")] = {find_newline, "start_of_line"},
        [sbyte('"')] = {close_string, "inside_key"},
        [sbyte("'")] = {close_literal_string, "inside_key"},
        [sbyte("[")] = {create_table, "table"},
        [sbyte("=")] = {error_invalid_state, "error"},
        [sbyte("}")] = {close_inline_table, "?"},
        [0] = {close_bare_string, "inside_key"},
    },
    ["table"] = {
        [sbyte('"')] = {close_string, "inside_table"},
        [sbyte("'")] = {close_literal_string, "inside_table"},
        [0] = {close_bare_string, "inside_table"},
    },
    ["inside_table"] = {
        [sbyte(".")] = {add_table_dot, "table"},
        [sbyte("]")] = {close_table, "wait_for_newline"},
        [0] = {error_invalid_state, "error"}
    },
    ["key"] = {
        [sbyte('"')] = {close_string, "inside_key"},
        [sbyte("'")] = {close_literal_string, "inside_key"},
        [sbyte("}")] = {close_inline_table, "?"},
        [sbyte("\r")] = {find_newline, "key"},
        [sbyte("\n")] = {find_newline, "key"},
        [sbyte("#")] = {find_newline, "key"},
        [0] = {close_bare_string, "inside_key"},
    },
    ["inside_key"] = {
        [sbyte(".")] = {assign_key, "key"},
        [sbyte("=")] = {assign_key, "value"},
        [0] = {error_invalid_state, "error"}
    },
    ["value"] = {
        [sbyte("'")] = {close_literal_string, "assign"},
        [sbyte('"')] = {close_string, "assign"},
        [sbyte("{")] = {create_inline_table, "key"},
        [sbyte("[")] = {create_array, "array"},
        [sbyte("\n")] = {error_invalid_state, "error"},
        [sbyte("\r")] = {error_invalid_state, "error"},
        [0] = {close_other_value, "assign"},
    },
    ["array"] = {
        [sbyte("'")] = {close_literal_string, "inside_array"},
        [sbyte('"')] = {close_string, "inside_array"},
        [sbyte("[")] = {create_array, "array"},
        [sbyte("]")] = {close_array, "?"}, -- depends if it's nested. either assign or inside_array
        [sbyte("#")] = {find_newline, "array"},
        [sbyte("\r")] = {find_newline, "array"},
        [sbyte("\n")] = {find_newline, "array"},
        [sbyte("{")] = {create_inline_table, "key"},
        [0] = {close_other_value, "inside_array"},
    },
    ["inside_array"] = {
        [sbyte(",")] = {add_array_comma, "array"},
        [sbyte("]")] = {close_array, "?"}, -- depends if it's nested. either assign or inside_array
        [sbyte("}")] = {close_inline_table, "?"},
        [sbyte("#")] = {find_newline, "inside_array"},
        [sbyte("\r")] = {find_newline, "inside_array"},
        [sbyte("\n")] = {find_newline, "inside_array"},
        [0] = {error_invalid_state, "error"}
    },
    ["assign"] = {
        [sbyte(",")] = {assign_value, "wait_for_key"},
        [sbyte("}")] = {close_inline_table, "?"},
        [0] = {assign_value, "wait_for_newline"}
    },
    ["wait_for_key"] = {
        [sbyte(",")] = {skip_comma, "key"},
    },
    ["wait_for_newline"] = {
        [sbyte("#")] = {find_newline, "start_of_line"},
        [sbyte("\r")] = {find_newline, "start_of_line"},
        [sbyte("\n")] = {find_newline, "start_of_line"},
        [0] = {error_invalid_state, "error"}
    }
}

local function generic_type_conversion<T>(raw_value: string): T return raw_value as T end

function tinytoml.parse(filename: string, options?: TinyTomlOptions): {string:any}
    local sm: StateMachine = {}

    local default_options: TinyTomlOptions = {
        max_nesting_depth = 1000,
        max_filesize = 100000000,
        load_from_string = false,
        encode_date_and_times_as = "string",
        type_conversion = {
            ["datetime"] = generic_type_conversion,
            ["datetime-local"] = generic_type_conversion,
            ["date-local"] = generic_type_conversion,
            ["time-local"] = generic_type_conversion
        }
    }

    if options then
        -- type check all the options!
        if options.max_nesting_depth ~= nil then
            assert(type(options.max_nesting_depth) == "number", "the tinytoml option 'max_nesting_depth' takes in a 'number'. You passed in the value '" .. tostring(options.max_nesting_depth) .. "' of type '" .. type(options.max_nesting_depth) .. "'")
        end

        if options.max_filesize ~= nil then
            assert(type(options.max_filesize) == "number", "the tinytoml option 'max_filesize' takes in a 'number'. You passed in the value '" .. tostring(options.max_filesize) .. "' of type '" .. type(options.max_filesize) .. "'")
        end

        if options.load_from_string ~= nil then
            assert(type(options.load_from_string) == "boolean", "the tinytoml option 'load_from_string' takes in a 'function'. You passed in the value '" .. tostring(options.load_from_string) .. "' of type '" .. type(options.load_from_string) .. "'")
        end

        if options.encode_date_and_times_as ~= nil then
            assert(type(options.encode_date_and_times_as) == "string", "the tinytoml option 'encode_date_and_times_as' takes in either the 'string' or 'table' (as type 'string'). You passed in the value '" .. tostring(options.encode_date_and_times_as) .. "' of type '" .. type(options.encode_date_and_times_as) .. "'")
        end

        if options.type_conversion ~= nil then
            assert(type(options.load_from_string) == "table", "the tinytoml option 'type_conversion' takes in a 'table'. You passed in the value '" .. tostring(options.type_conversion) .. "' of type '" .. type(options.type_conversion) .. "'")
            for key, value in pairs(options.type_conversion) do
                assert(type(key) == "string")
                if not default_options.type_conversion[key] then
                    error("")
                end
                assert(type(value) == "function")
            end
        end

        -- put in the defaults
        options.max_nesting_depth = options.max_nesting_depth or default_options.max_nesting_depth
        options.max_filesize = options.max_filesize or default_options.max_filesize
        options.load_from_string = options.load_from_string or default_options.load_from_string
        options.encode_date_and_times_as = options.encode_date_and_times_as or default_options.encode_date_and_times_as
        options.type_conversion = options.type_conversion or default_options.type_conversion
        
        -- verify/setup the last couple of things
        if options.load_from_string == true then
            sm.input = filename
            sm.filename = "string input"
        end

        -- ensure a value is set for all the options.type_conversion
        for key, value in pairs(default_options.type_conversion) do
            if options.type_conversion[key] == nil then
                options.type_conversion[key] = value
            end
        end

    else
        options = default_options
    end

    -- finally set sm.options
    sm.options = options

    if options.load_from_string == false then
        local file = io.open(filename, "r")
        if not file then error("Unable to open file: '" .. filename .. "'") end
        if file:seek("end") > options.max_filesize then error("Filesize is larger than 100MB. If this is intentional, please set the 'max_filesize' (in bytes) in options") end
        file:seek("set")
        sm.input = file:read("*all")
        file:close()
        sm.filename = filename
    end

    sm.i = 1
    sm.keys = {}
    sm.arrays = {}
    sm.output = {}
    sm.meta_table = {}
    sm.line_number = 1
    sm.line_number_char_index = 1
    sm.nested_arrays = 0
    sm.inline_table_backup = {}
    sm.nested_inline_tables = 0
    sm.table_type = "table"
    sm.input_length = #sm.input
    sm.current_table = sm.output as {any}
    sm.current_meta_table = sm.meta_table

    -- empty file is just an empty array
    if sm.input_length == 0 then return {} end

    local valid, line_number, line_number_start, message = validate_utf8(sm.input, true)
    if not valid then
        sm.line_number = line_number
        sm.line_number_char_index = line_number_start
        _error(sm, message, "preliminaries")
    end

    sm.mode = "start_of_line"
    local dynamic_next_mode: states = "start_of_line"
    local transition: {function, string} = nil
    sm._, sm.i = sm.input:find("[^ \t]", sm.i)

    -- just an file with whitespace and nothing else...
    if not sm.i then return {} end
    
    while sm.i <= sm.input_length do
        sm.byte = sbyte(sm.input, sm.i)

        transition = transitions[sm.mode][sm.byte]
        if transition == nil then
            transition = transitions[sm.mode][0]
        end
        -- print(sm.line_number, sm.mode, sm.i, string.char(sm.byte), transition[2])
        if transition[2] == "?" then
            dynamic_next_mode = transition[1](sm) as states
            sm.mode = dynamic_next_mode
        else
            transition[1](sm)
            sm.mode = transition[2] as states
        end

        sm._, sm.i = sm.input:find("[^ \t]", sm.i)
        if sm.i == nil then
            break
        end
    end

    if sm.mode == "assign" then
        -- small workaround to avoid nil checking in assign_value
        sm.i = sm.input_length
        assign_value(sm)
    end
    if sm.mode == "inside_array" or sm.mode == "array" then
        _error(sm, "Unable to find closing bracket of array", "array")
    end
    if sm.mode == "key" then
        _error(sm, "Incorrect formatting for key", "keys")
    end
    if sm.mode == "value" then
        _error(sm, "Key has been assigned, but value doesn't seem to exist", "keyvalue-pair")
    end
    if sm.nested_inline_tables ~= 0 then
        _error(sm, "Unable to find closing bracket of inline table", "inline-table")
    end

    return sm.output
end

-- Encoder code is below!

local record EncoderOptions
    allow_multiline_strings: boolean
end

local function is_array(input_table: any): boolean
    local count = #(input_table as {any})
    return count > 0 and next(input_table as {any}, count) == nil
end

local short_sequences: {integer:string} = {
    [sbyte('\b')] = '\\b',
    [sbyte('\t')] = '\\t',
    [sbyte('\n')] = '\\n',
    [sbyte('\f')] = '\\f',
    [sbyte('\r')] = '\\r',
    [sbyte('\t')] = '\\t',
    [sbyte('\\')] = '\\\\',
    [sbyte('"')] = '\\"',
}

local function escape_string(str: string, multiline: boolean, is_key: boolean): string

    -- possibly a date or a time!
    if not is_key and #str >= 5 and str:find("%d%d") then
        -- since Lua doesn't have any datetime format, going to check if the string is 
        -- a valid datetime and return accordingly
        
        -- setting up a _very_ basic StateMachine
        local sm: StateMachine = {input=str, i=1, line_number=1, line_number_char_index=1}
        sm.options = {}
        sm.options.type_conversion = {
            ["datetime"] = generic_type_conversion,
            ["datetime-local"] = generic_type_conversion,
            ["date-local"] = generic_type_conversion,
            ["time-local"] = generic_type_conversion
        }

        -- performing the same setup as in close_other_value, should set values correctly to run validate_datetime
        sm._, sm.end_seq, sm.match = sm.input:find("^([^ #\r\n,%[{%]}]+)", sm.i)
        sm.i = sm.end_seq + 1

        if validate_datetime(sm, sm.match) then
            if sm.value_type == "datetime" or sm.value_type == "datetime-local" or
                sm.value_type == "date-local" or sm.value_type == "time-local" then
                return sm.value as string
            end
        end
    end

    local byte: integer
    local found_newline = false
    local final_string = string.gsub(str, '[%z\x01-\x1f\x7f\\"]', function(c: string): string
        byte = sbyte(c)
        if short_sequences[byte] then
            if multiline and (byte == chars.CR or byte == chars.LF) then
                found_newline = true
                return c
            else
                return short_sequences[byte]
            end
        else
            return string.format("\\x%02x", byte)
        end
    end)
    if found_newline then
        final_string = '"""' .. final_string .. '"""'
    else
        final_string = '"' .. final_string .. '"'
    end

    if not validate_utf8(final_string, true) then
        error("String is not valid UTF-8, cannot encode to TOML")
    end
    return final_string

end

local function escape_key(str: string): string
    if str:find("^[A-Za-z0-9_-]+$") then
        return str
    else
        return escape_string(str, false, true)
    end
end

local to_inf_and_beyound: {string: boolean} = {
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
   -- fallback in case we can't get the precision.
   return tostring(x)
end

local function encode_element(element: any, allow_multiline_strings: boolean): string
    if type(element) == "table" then
        local encoded_string = {}
        if is_array(element) then
            table.insert(encoded_string, "[")

            local remove_trailing_comma = false
            for _, array_element in ipairs(element as {any}) do
                remove_trailing_comma = true
                table.insert(encoded_string, encode_element(array_element, allow_multiline_strings))
                table.insert(encoded_string, ", ")
            end
            if remove_trailing_comma then table.remove(encoded_string) end

            table.insert(encoded_string, "]")

            return table.concat(encoded_string)

        else
            table.insert(encoded_string, "{")

            local remove_trailing_comma = false
            for k, v in pairs(element as {string: any}) do
                remove_trailing_comma = true
                table.insert(encoded_string, k)
                table.insert(encoded_string, " = ")
                table.insert(encoded_string, encode_element(v, allow_multiline_strings))
                table.insert(encoded_string, ", ")
            end
            if remove_trailing_comma then table.remove(encoded_string) end
            
            table.insert(encoded_string, "}")

            return table.concat(encoded_string)

        end

    elseif type(element) == "string" then
        return escape_string(element as string, allow_multiline_strings, false)
    
    elseif type(element) == "number" then
        return float_to_string(element as number)
    
    elseif type(element) == "boolean" then
        return tostring(element)

    else
        error("Unable to encode type '" .. type(element) .. "' into a TOML type")
    end
end

local function encode_depth(encoded_string: {string}, depth: {string})
    table.insert(encoded_string, '\n[')
    table.insert(encoded_string, table.concat(depth, '.'))
    table.insert(encoded_string, ']\n')
end

local function encoder(input_table: any, encoded_string: {string}, depth: {string}, options: EncoderOptions): {string}
    local printed_table_info = false
    for k, v in pairs(input_table as {string: any}) do
        if type(v) ~= "table" or (type(v) == "table" and is_array(v)) then
            if not printed_table_info and #depth > 0 then
                encode_depth(encoded_string, depth)
                printed_table_info = true
            end
            table.insert(encoded_string, escape_key(k))
            table.insert(encoded_string, " = ")
            local status, error_or_encoded_element = pcall(encode_element, v, options.allow_multiline_strings)
            if not status then
                local error_message = {"\n\nWhile encoding '"}
                local _: integer
                if #depth > 0 then
                    error_message[#error_message + 1] = table.concat(depth, ".")
                    error_message[#error_message + 1] = "."
                end
                error_message[#error_message + 1] = escape_key(k)
                error_message[#error_message + 1] = "', received the following error message:\n\n"
                -- _, _, error_or_encoded_element = error_or_encoded_element:find(".-:.-: (.*)")
                error_message[#error_message + 1] = error_or_encoded_element
                error(table.concat(error_message))
            end
            table.insert(encoded_string, error_or_encoded_element as string)
            table.insert(encoded_string, "\n")
        end
    end
    for k, v in pairs(input_table as {string: any}) do
        if type(v) == "table" and not is_array(v) then
            if next(v as {any:any}) == nil then
                table.insert(depth, escape_key(k))
                encode_depth(encoded_string, depth)
                table.remove(depth)

            -- descend
            else
                table.insert(depth, escape_key(k))
                encoder(v, encoded_string, depth, options)
                table.remove(depth)
            end
        end
    end
    return encoded_string
end

function tinytoml.encode(input_table: any, options?: EncoderOptions): string
    options = options or {
        allow_multiline_strings = false
    }
    return table.concat(encoder(input_table, {}, {}, options))
end

return tinytoml

