package = "tinytoml"
version = "0.0.2-1"

source = {
    url = "git://github.com/FourierTransformer/tinytoml.git",
    tag = "0.0.2"
}

description = {
    summary = "A pure Lua TOML parser",
    detailed = [[
   tinytoml is an easy to use TOML parser library for Lua. It can read in TOML files or load them from a string.
   It supports all TOML 1.0.0 features including parsing strings, numbers, datetimes, arrays, inline-tables and even validating UTF-8 with good error messages if anything fails!
  ]],
    homepage = "https://github.com/FourierTransformer/tinytoml",
    maintainer = "Fourier Transformer <ftransformer@protonmail.com>",
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
