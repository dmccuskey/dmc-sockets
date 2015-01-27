# dmc-sockets

try:
	if not gSTARTED: print( gSTARTED )
except:
	MODULE = "dmc-sockets"
	include: "../DMC-Corona-Library/snakemake/Snakefile"

module_config = {
	"name": "dmc-sockets",
	"module": {
		"dir": "dmc_corona",
		"files": [
			"dmc_sockets.lua",
			"dmc_sockets/tcp.lua",
			"dmc_sockets/async_tcp.lua",
			"dmc_sockets/ssl_params.lua"
		],
		"requires": [
			"dmc-corona-boot",
			"DMC-Lua-Library",
			"dmc-objects",
			"dmc-utils"
		]
	},
	"examples": {
		"dir": "examples",
		"apps": [
			{
				"dir": "dmc-sockets-asynctcp",
				"requires": []
			},
			{
				"dir": "dmc-sockets-basic",
				"requires": []
			}
		]
	},
	"tests": {
		"files": [],
		"requires": []
	}
}

register( "dmc-sockets", module_config )

