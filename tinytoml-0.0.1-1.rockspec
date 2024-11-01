package = "tinytoml"
version = "0.0.1-1"

source = {
	url = "git://github.com/FourierTransformer/tinytoml.git",
	tag = "0.0.1"
}

description = {
	summary = "A pure Lua TOML parser",
	detailed = [[
   tinytoml is an easy to use TOML parser library for Lua. It can read in TOML files or load from a string.
   It supports all TOML 1.0.0 features including validating UTF-8 and datetimes with good error messages.
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
}


