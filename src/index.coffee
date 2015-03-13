require 'string.prototype.startswith'
require 'string.prototype.includes'

stream = require 'stream'
util = require 'util'

Vector = require './Vector'
Polygon = require './Polygon'
errors = require './errors'
AsciiParser = require './AsciiParser'
BinaryParser = require './BinaryParser'

Transform = stream.Transform
Readable = stream.Readable


toBuffer = (arrayBuffer) ->
	if Buffer and Buffer.isBuffer arrayBuffer
		return arrayBuffer
	else
		buffer = new Buffer arrayBuffer.byteLength
		view = new Uint8Array arrayBuffer
		i = 0

		while i < buffer.length
			buffer[i] = view[i]
			++i

		return buffer

containsKeywords = (stlString) ->
	return stlString.startsWith('solid') and
			stlString.includes('facet') and
			stlString.includes ('vertex')


class GenericStream extends Readable
	constructor: (@data, @options = {}) ->
		super @options

	_read: () ->
		@push @data
		@push null


class StlParser extends Transform
	constructor: (@options = {}) ->
		@firstCall = true
		@options.writableObjectMode ?= false
		@options.readableObjectMode ?= true
		super @options

	_flush: (done) ->
		@parser.end()
		done()

	_transform: (chunk, encoding, done) ->

		if @firstCall
			@firstCall = false
			if chunk.toString().startsWith('solid') or @options.type is 'ascii'
				@parser = new AsciiParser {format: @options.format}
			else
				@parser = new BinaryParser {format: @options.format}

			@parser.on 'data', (data) =>
				if @options.readableObjectMode
					@push data
				else
					@push JSON.stringify data
					@push '\n'

			@parser.on 'end', () =>
				@push null

			@parser.on 'error', (error) ->
				throw error

			@parser.on 'warning', (warning) =>
				@emit 'warning', warning

		@parser.write chunk, () ->
			done()



module.exports = (fileContent, options) ->

	if typeof fileContent is 'undefined' or
		(typeof fileContent is 'object' and
		not Buffer.isBuffer(fileContent)) and
		not fileContent instanceof ArrayBuffer
			# fileContent contains options object
			return new StlParser fileContent

	if options?.type is 'ascii' or typeof fileContent is 'string'
		if containsKeywords fileContent
			return new GenericStream fileContent
				.pipe new StlParser {type: 'ascii', format: 'json'}
		else
			throw new Error 'STL string does not contain all stl-keywords!'
	else
		if options?.type is 'binary'
			return new GenericStream fileContent
				.pipe new StlParser {type: 'binary', format: 'json'}

		if Buffer and Buffer.isBuffer fileContent
			stlString = fileContent.toString()

		else if fileContent instanceof ArrayBuffer
			fileContent = toBuffer fileContent
			stlString = fileContent.toString()
		else
			throw new Error fileContent + ' has an unsupported format!'

		if containsKeywords stlString
			return new GenericStream stlString
				.pipe new StlParser {type: 'ascii', format: 'json'}

		new GenericStream fileContent
			.pipe new StlParser {type: 'binary', format: 'json'}
