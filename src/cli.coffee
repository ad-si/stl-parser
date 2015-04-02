fs = require 'fs'
path = require 'path'

#yaml = require 'js-yaml'
#bufferConverter = require 'buffer-converter'

StlParser = require './StlParser'


module.exports = () ->
	if process.stdin.isTTY

		console.log('Stl-parser must be used by piping into it')

	else
		process.stdin
		.pipe new StlParser({
			readableObjectMode: false
		})
		.pipe process.stdout
