require 'string.prototype.startswith'

stream = require 'stream'
clone = require 'clone'

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
			@emit(
				'error',
				new Error 'Provided STL-string must not be empty'
			)

		done()

	_transform: (chunk, encoding, done) ->
		if @firstCall
			@firstCall = false

			if (@options.type isnt 'binary' and chunk.toString().startsWith(
				'solid')) or @options.type is 'ascii'
				@parser = new AsciiParser clone @options
				if @options.format isnt 'json'
					@push(
						if @options.readableObjectMode
						then  {type: 'ascii'}
						else  JSON.stringify(type: 'ascii') + '\n'
					)
			else
				@parser = new BinaryParser clone @options
				if @options.format isnt 'json'
					@push(
						if @options.readableObjectMode
						then  {type: 'ascii'}
						else  JSON.stringify(type: 'binary') + '\n'
					)

			@parser.on 'data', (data) =>
				if @options.readableObjectMode
					@push data
				else
					@push JSON.stringify(data) + '\n'

			@parser.on 'end', () =>
				@push null

			@parser.on 'error', (error) =>
				@emit 'error', error

			@parser.on 'warning', (warning) =>
				@emit 'warning', warning

			@parser.on 'progress', (progress) =>
				@emit 'progress', progress

		@parser.write chunk, () ->
			done()


module.exports = StlParser
