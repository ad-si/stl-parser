require 'string.prototype.startswith'

stream = require 'stream'

AsciiParser = require './AsciiParser'
BinaryParser = require './BinaryParser'


class StlParser extends stream.Transform
	constructor: (@options = {}) ->
		@firstCall = true
		@options.writableObjectMode ?= false
		@options.readableObjectMode ?= true
		super @options

	_flush: (done) ->
		if @parser
			@parser.end()
		else
			@emit 'error', 'Provided STL-string must not be empty'

		done()

	_transform: (chunk, encoding, done) ->
		if @firstCall
			@firstCall = false
			if chunk.toString().startsWith('solid') or @options.type is 'ascii'
				@parser = new AsciiParser {
					format: @options.format
					blocking: @options.blocking
				}
			else
				@parser = new BinaryParser {
					format: @options.format
					blocking: @options.blocking
				}

			@parser.on 'data', (data) =>
				if @options.readableObjectMode
					@push data
				else
					@push JSON.stringify data
					@push '\n'

			@parser.on 'end', () =>
				@push null

			@parser.on 'error', (error) =>
				@emit 'error', error

			@parser.on 'warning', (warning) =>
				@emit 'warning', warning

		@parser.write chunk, () ->
			done()


module.exports = StlParser
