util = require 'util'
stream = require 'stream'

bufferTrim = require 'buffertrim'

Ascii = require './Ascii'
Binary = require './Binary'
Polygon = require './Polygon'
Vector = require './Vector'


class BinaryParser extends stream.Transform
	constructor: (@options = {}) ->
		@options.writableObjectMode ?= false
		@options.readableObjectMode ?= true
		super @options

		@internalBuffer = new Buffer(0)
		@header = ''
		@facesCounter = 0
		@countedFaces = 0
		@cursor = 80
		@currentModel = {}
		@currentFace = {}

		@headerByteCount = 80        # 80 * UInt8
		@vertexByteCount = 12         # 3 * Float
		@attributeByteCount = 2      # 1 * UInt16
		@facesCounterByteCount = 4   # 1 x UInt32
		@faceByteCount = 50          # 4 * vertexByteCount + attributeByteCount
		@facesOffset = @headerByteCount + @facesCounterByteCount
		@coordinateByteCount = 4


	_flush: (done) =>
		done null, @internalBuffer


	_transform: (chunk, encoding, done) ->

		@internalBuffer = Buffer.concat [@internalBuffer, chunk]

		while @cursor <= @internalBuffer.length

			if @cursor is @headerByteCount
				@header = bufferTrim.trimEnd(
					@internalBuffer.slice(0, @headerByteCount)
				).toString()
				@currentModel.name = @header
				@push @currentModel
				@cursor += @facesCounterByteCount
				continue

			if @cursor is @facesOffset
				@facesCounter = @internalBuffer.readUInt32LE @headerByteCount
				# TODO: Add warning for wrong number
				@cursor += @faceByteCount
				continue

			if @cursor = (@facesOffset + (@countedFaces + 1) * @faceByteCount)
				@cursor -= @faceByteCount
				@currentFace = {
					normal: {
						x: @internalBuffer.readFloatLE(
							@cursor
						)
						y: @internalBuffer.readFloatLE(
							@cursor += @coordinateByteCount
						)
						z: @internalBuffer.readFloatLE(
							@cursor += @coordinateByteCount
						)
					}
				}

				@currentFace.vertices = []

				for i in [0..2]
					@currentFace.vertices.push {
						x: @internalBuffer.readFloatLE(
							@cursor += @coordinateByteCount
						)
						y: @internalBuffer.readFloatLE(
							@cursor += @coordinateByteCount
						)
						z: @internalBuffer.readFloatLE(
							@cursor += @coordinateByteCount
						)
					}

				@currentFace.attribute = @internalBuffer
					.readUInt16LE @cursor += @coordinateByteCount

				@cursor += @attributeByteCount

				@push @currentFace

				@cursor += @faceByteCount
				@countedFaces++

		done()


module.exports = BinaryParser
