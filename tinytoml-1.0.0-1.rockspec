package = "tinytoml"
version = "1.0.0-1"

source = {
    url = "git://github.com/FourierTransformer/tinytoml.git",
    tag = "1.0.0"
}

description = {
    summary = "A pure Lua TOML parser",
    detailed = [[
   tinytoml is an easy to use TOML parser library for Lua. It can read in TOML files or load them from a string.
   It supports all TOML 1.1.0 features including parsing strings, numbers, datetimes, arrays, inline-tables and even validating UTF-8 with good error messages if anything fails!
  ]],
    homepage = "https://github.com/FourierTransformer/tinytoml",
    license = "MIT"
}

dependencies = {
    "lua >= 5.1",
}

build = {
    type = "builtin",
    modules = {
        ["tinytoml"] = "tinytoml.lua"
    },
    install = {
        lua = {
            ["tinytoml"] = "tinytoml.tl"
        }
    }
}

