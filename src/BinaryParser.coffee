util = require 'util'
stream = require('stream')

Ascii = require './Ascii'
Binary = require './Binary'
Polygon = require './Polygon'
Vector = require './Vector'

Transform = stream.Transform


class BinaryParser extends Transform
	constructor: (options = {}) ->
		options.writableObjectMode ?= true
		super options

	_transform: () ->
		# TODO: Enable streaming functionality
		reader = new DataView @stlBuffer, 80
		numTriangles = reader.getUint32 0, true

		#check if file size matches with numTriangles
		dataLength = @stlBuffer.byteLength - 80 - 4
		polyLength = 50
		calcDataLength = polyLength * numTriangles

		if calcDataLength > dataLength
			throw new FileError null, calcDataLength, dataLength

		binaryIndex = 4
		while (binaryIndex - 4) + polyLength <= dataLength
			poly = new Polygon()
			nx = reader.getFloat32 binaryIndex, true
			binaryIndex += 4
			ny = reader.getFloat32 binaryIndex, true
			binaryIndex += 4
			nz = reader.getFloat32 binaryIndex, true
			binaryIndex += 4
			poly.setNormal new Vector(nx, ny, nz)

			for i in [0..2]
				vx = reader.getFloat32 binaryIndex, true
				binaryIndex += 4
				vy = reader.getFloat32 binaryIndex, true
				binaryIndex += 4
				vz = reader.getFloat32 binaryIndex, true
				binaryIndex += 4
				poly.addVertex new Vector(vx, vy, vz)

			# Skip uint 16
			binaryIndex += 2
			@stl.addPolygon poly

		return @stl


module.exports = BinaryParser
