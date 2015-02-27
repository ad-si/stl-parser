util = require 'util'
stream = require 'stream'

Ascii = require './Ascii'
Binary = require './Binary'
Polygon = require './Polygon'
Vector = require './Vector'

Transform = stream.Transform


class AsciiParser extends Transform
	constructor: (@options = {}) ->
		@options.writableObjectMode ?= false
		@options.readableObjectMode ?= true
		super @options

		@internalBuffer = ''
		@last = 'root'
		@currentModel = null
		@currentFace = null
		@faceCounter = 0


	getNextWord: () =>
		words = @internalBuffer.match(/\S+/)

		@internalBuffer = @internalBuffer.trim()

		if (words is null) or (words[0].length is @internalBuffer.length)
			return null
		else
			@internalBuffer = @internalBuffer
				.trim()
				.substr(words[0].length + 1)
			return words[0]


	_flush: (done) =>
		done null, @internalBuffer


	_transform: (chunk, encoding, done) =>

		@internalBuffer += chunk.toString()

		while word = @getNextWord()

			# If statements are sorted descendingly
			# by relative frequency of the corresponding keyword
			# in STL-files

			if @last is 'vertex'
				@currentVertex.x = Number word
				@last = 'vertex-x'
				continue

			if @last is 'vertex-x'
				@currentVertex.y = Number word
				@last = 'vertex-y'
				continue

			if @last is 'vertex-y'
				@currentVertex.z = Number word
				@last = 'vertex-z'
				continue


			if word is 'vertex'
				if @last is 'loop'
					@currentFace.vertices = []
					@currentFace.number = ++@faceCounter

				if @last is 'vertex-z' or @last is 'loop'
					@currentVertex = {
						x: null,
						y: null,
						z: null
					}
					@currentFace.vertices.push @currentVertex
					@last = 'vertex'
				else
					throw new Error 'Unexpected "vertex" after ' + @last

				continue

			if word is 'facet'
				if @last is 'solid' or @last is 'name'
					@push @currentModel
					@last = 'facet'
				else if @last is 'endfacet'
					@last = 'facet'
				else
					throw new Error('Unexpected facet after ' + @last)
				continue

			if word is 'normal'
				if @last is 'facet'
					@currentFace = {
						normal: {x: null, y: null, z: null}
					}
					@last = 'normal'
					continue
				else
					throw new Error('Unexpected normal after ' + @last)

			if @last is 'normal'
				@currentFace.normal.x = Number word
				@last = 'normal-x'
				continue

			if @last is 'normal-x'
				@currentFace.normal.y = Number word
				@last = 'normal-y'
				continue

			if @last is 'normal-y'
				@currentFace.normal.z = Number word
				@last = 'normal-z'
				continue

			if word is 'outer'
				if @last is 'normal-z'
					@last = 'outer'
					continue
				else
					throw Error 'Unexpected "outer" after ' + @last

			if word is 'loop'
				if @last is 'outer'
					@last = 'loop'
					continue
				else
					throw Error 'Unexpected "loop" after ' + @last

			if word is 'endloop'
				if @last is 'vertex-z'
					@last = 'endloop'
					continue
				else
					throw Error 'Unexpected "endloop" after ' + @last

			if word is 'endfacet'
				if @last is 'endloop'
					@push @currentFace
					@last = 'endfacet'
					continue
				else
					throw Error 'Unexpected "endfacet" after ' + @last

			if word is 'endsolid'
				if @last is 'endfacet'
					@last = 'endsolid'
					@push null
					continue
				else
					throw Error 'Unexpected "endsolid" after ' + @last

			if word is 'solid'
				if @last is 'root'
					@currentModel = {name: null}
					@last = 'solid'
					continue
				else
					throw new Error 'Unexpected "solid" after ' + @last

			if @last is 'solid'
				@currentModel.name = word
				@last = 'name'

		done()

		###

		model = null
		currentPoly = null

		switch word
		when
		'solid'
		model.name = @asciiStl.nextText()

		when
		'facet'
		if (currentPoly?)
			@emit('FacetWarning')
			model.faces.addPolygon currentPoly
			currentPoly = null
		currentPoly = new Polygon()

		when
		'endfacet'
		if !(currentPoly?)
			@emit(
				'FacetWarning',
				{message: 'Facet was ended without beginning it!'}
			)
		else
			model.faces.push currentPoly
			currentPoly = null

		when
		'normal'
		nx = parseFloat @asciiStl.nextText()
		ny = parseFloat @asciiStl.nextText()
		nz = parseFloat @asciiStl.nextText()

		if (!(nx?) or !(ny?) or !(nz?))
			@emit('NormalWarning')
		else
			if not (currentPoly?)
				@emit(
					'NormalWarning',
					{
						message: 'Normal definition
											without an existing polygon!'
					}
				)
				currentPoly = new Polygon()
			currentPoly.setNormal new Vector(nx, ny, nz)

		when
		'vertex'
		vx = parseFloat @asciiStl.nextText()
		vy = parseFloat @asciiStl.nextText()
		vz = parseFloat @asciiStl.nextText()

		if (!(vx?) or !(vy?) or !(vz?))
			@emit('VertexWarning')

		else
			if not (currentPoly?)
				throw new VertexError 'Point definition without
													an existing polygon!'
				currentPoly = new Polygon()

			if currentPoly.vertices.length >= 3
				@emit(
					'VertexWarning',
					{message: 'More than 3 vertices per facet!'}
				)
			else
				currentPoly.addVertex new Vector(vx, vy, vz)
		###

module.exports = AsciiParser
