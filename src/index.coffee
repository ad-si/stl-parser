require 'string.prototype.startswith'
require 'string.prototype.includes'

stream = require 'stream'
util = require 'util'

textEncoding = require 'text-encoding'
bufferConverter = require 'buffer-converter'

Vector = require './Vector'
Polygon = require './Polygon'
errors = require './errors'
AsciiParser = require './AsciiParser'
BinaryParser = require './BinaryParser'

Transform = stream.Transform
Readable = stream.Readable


containsKeywords = (stlString) =>
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

			@parser.on 'error', (error) =>
				throw error

		@parser.write chunk, () ->
			done()



module.exports = (fileContent, options) ->

	if typeof fileContent is 'undefined' or
		(typeof fileContent is 'object' and not Buffer.isBuffer(fileContent))
			# fileContent contains options object
			return new StlParser fileContent

	if options?.type is 'ascii' or typeof fileContent is 'string'
		if containsKeywords fileContent
			return new GenericStream(fileContent)
				.pipe new StlParser {type: 'ascii', format: 'json'}
		else
			throw new Error 'STL string does not contain all stl-keywords!'

	else
		if options?.type is 'binary'
			return new GenericStream(fileContent)
				.pipe new StlParser({type: 'binary'})

		# TODO: Remove if branch when textEncoding is fixed under node 0.12
		# https://github.com/inexorabletash/text-encoding/issues/29
		if Buffer
			if Buffer.isBuffer fileContent
				stlString = bufferConverter
				.toBuffer(fileContent)
				.toString()
			else
				throw new Error "#{typeof fileContent} is no
						supported data-format!"
		else
			stlString = textEncoding
			.TextDecoder 'utf-8'
			.decode new Uint8Array fileContent

		if containsKeywords stlString
			return new GenericStream(stlString)
				.pipe new StlParser {type: 'ascii', format: 'json'}

		new GenericStream(fileContent)
			.pipe new StlParser({type: 'binary'})
