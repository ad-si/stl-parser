fs = require 'fs'
path = require 'path'

chalk = require 'chalk'

StlParser = require './StlParser'


stlParser = new StlParser {
	readableObjectMode: false
}


module.exports = () ->
	if process.stdin.isTTY
		console.error chalk.red 'Stl-parser must be used by piping into it'

	else
		process.stdin
		.pipe stlParser
		.pipe process.stdout

		stlParser.on 'error', (error) ->
			console.error chalk.red error

		stlParser.on 'warning', (warning) ->
			console.warn chalk.yellow warning
