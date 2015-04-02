require 'string.prototype.startswith'
require 'string.prototype.includes'

util = require 'util'

Vector = require './Vector'
Polygon = require './Polygon'
errors = require './errors'
GenericStream = require './GenericStream'
StlParser = require './StlParser'


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
