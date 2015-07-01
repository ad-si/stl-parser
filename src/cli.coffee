fs = require 'fs'
path = require 'path'

chalk = require 'chalk'

StlParser = require './StlParser'


module.exports = (options) ->

	if options.ascii
		options.type = 'ascii'
	if options.binary
		options.type = 'binary'

	options.readableObjectMode = false

	stlParser = new StlParser options

	if process.stdin.isTTY
		console.error chalk.red 'Stl-parser must be used by piping into it'

	else
		process.stdin
		.pipe stlParser
		.pipe process.stdout

		stlParser.on 'error', (error) ->
			console.error chalk.red error.stack

		stlParser.on 'warning', (warning) ->
			console.warn chalk.yellow 'Warning:', warning

		stlParser.on 'debug', (debugInfo) ->
			console.warn chalk.cyan 'Debug:', debugInfo
