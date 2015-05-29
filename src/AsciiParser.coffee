util = require 'util'
stream = require 'stream'

Ascii = require './Ascii'
Binary = require './Binary'
Polygon = require './Polygon'
Vector = require './Vector'
toNumber = require './toNumber'

Transform = stream.Transform


class AsciiParser extends Transform
	constructor: (@options = {}) ->
		@options.writableObjectMode ?= false
		@options.readableObjectMode ?= true
		@options.blocking ?= true
		@options.format ?= 'jsonl'
		@options.discardExcessVertices ?= true

		super @options

		@debugBuffer = ''
		@internalBuffer = ''
		@last = 'root'
		@currentModel = {
			name: null
			isClosed: false
		}
		@currentFace = {
			number: 0
		}

		@countedFaces = 0
		@lineCounter = 1
		@characterCounter = 0


	getNextWord: () =>
		if /^\s*\n\s*/gi.test @internalBuffer then @lineCounter++

		whitespace = @internalBuffer.match /^\s+/

		if whitespace
			@characterCounter += whitespace[0].length
			@internalBuffer = @internalBuffer.substr whitespace[0].length

		words = @internalBuffer.match /^\S+/

		if (words is null) or (words[0].length is @internalBuffer.length)
			return null
		else
			@characterCounter += words[0].length
			@internalBuffer = @internalBuffer.substr words[0].length
			return words[0]


	_flush: (done) =>
		if @currentModel.name is null
			@emit(
				'error',
				new Error 'Provided ascii STL contains an invalid solid'
			)

		if not @currentModel.isClosed and @internalBuffer isnt 'endsolid'
			@emit(
				'error',
				new Error 'Provided ascii STL is not
				closed with endsolid keyword'
			)

		if @countedFaces is 0
			if @currentModel.name.length > 50
				@currentModel.name = @currentModel.name.substr(0,50) + '…'
			@emit(
				'warning',
				"Solid '#{@currentModel.name}'
				does not contain any faces"
			)

		done()


	_transform: (chunk, encoding, done) =>

		@internalBuffer += chunk.toString()

		while word = @getNextWord()

			# If statements are sorted descendingly
			# by relative frequency of the corresponding keyword
			# in STL-files

			if @last is 'vertex'
				try
					@currentVertex.x = toNumber word
				catch error
					@emit(
						'error',
						new Error "Unexpected '#{word}' instead of vertex x-value
						in face #{@currentFace.number}, line #{@lineCounter}"
					)
				@last = 'vertex-x'
				continue

			if @last is 'vertex-x'
				try
					@currentVertex.y = toNumber word
				catch error
					@emit(
						'error',
						new Error "Unexpected '#{word}' instead of vertex y-value
						in face #{@currentFace.number}, line #{@lineCounter}"
					)
				@last = 'vertex-y'
				continue

			if @last is 'vertex-y'
				try
					@currentVertex.z = toNumber word
				catch error
					@emit(
						'error',
						new Error "Unexpected '#{word}' instead of vertex z-value
						in face #{@currentFace.number}, line #{@lineCounter}"
					)
				@last = 'vertex-z'
				continue


			if word is 'vertex'
				if @last is 'vertex-z' or @last is 'loop'
					if @last is 'loop'
						@currentFace.vertices = []

					@currentVertex = {
						x: null,
						y: null,
						z: null
					}
					@currentFace.vertices.push @currentVertex

				else
					@emit(
						'error',
						new Error "Unexpected vertex after #{@last}
						in face #{@currentFace.number} in line #{@lineCounter}"
					)
				@last = 'vertex'
				continue


			if word is 'facet'
				@currentFace = {
					number: @countedFaces + 1
				}
				if @last is 'solid'
					if @options.format isnt 'json'
						@push @currentModel
				else if @last isnt 'endfacet'
					@emit(
						'error',
						new Error "Unexpected facet after #{@last}
						in face #{@currentFace.number} in line #{@lineCounter}"
					)

				@last = 'facet'
				continue


			if word is 'normal'
				if @last is 'facet'
					@currentFace.normal = {x: null, y: null, z: null}
				else
					@emit(
						'error',
						new Error "Unexpected normal after #{@last}"
					)

				@last = 'normal'
				continue

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
					@emit(
						'error',
						new Error "Unexpected outer after #{@last}
						in face #{@currentFace.number} in line #{@lineCounter}"
					)

			if word is 'loop'
				if @last isnt 'outer'
					@emit(
						'error',
						new Error "Unexpected loop after #{@last}
						in face #{@currentFace.number} in line #{@lineCounter}"
					)

				@last = 'loop'
				continue

			if word is 'endloop'
				if @last isnt 'vertex-z'
					@emit(
						'error',
						new Error "Unexpected endloop after #{@last}
						in face #{@currentFace.number} in line #{@lineCounter}"
					)

				else if @currentFace.vertices.length isnt 3
					@emit 'warning', "Face #{@currentFace.number} has
						#{@currentFace.vertices.length} instead of 3 vertices"

					if @currentFace.vertices.length > 3
						if @options.discardExcessVertices
							@currentFace.vertices.splice(3)
					else
						@currentFace = null

				@last = 'endloop'
				continue

			if word is 'endfacet'
				if @last is 'endloop'
					if @currentFace and @currentFace.vertices
						@countedFaces++
						if @options.format is 'json'
							@currentModel.faces.push @currentFace
						else
							@push @currentFace
				else
					@emit(
						'error',
						new Error "Unexpected endfacet after #{@last}
						in face #{@currentFace.number} in line #{@lineCounter}"
					)
				@last = 'endfacet'
				continue

			if word is 'endsolid'
				if @options.format is 'json' or @last is 'solid'
					@push @currentModel

				if @last is 'endfacet' or @last is 'solid'
					@currentModel.isClosed = true
				else
					@emit(
						'error',
						new Error "Unexpected endsolid after #{@last}
						in face #{@currentFace.number} in line #{@lineCounter}"
					)

				if @internalBuffer.trim() is @currentModel.name
					@push null

				@last = 'endsolid'
				continue

			if word is 'solid'
				if @last is 'root' or @last is 'endsolid'
					@currentModel = {
						name: null
						isClosed: false
					}
					@currentFace = {number: 0}
					if @options.format is 'json'
						@currentModel.faces = []
				else
					@emit(
						'error',
						new Error "Unexpected solid after #{@last}
						in face #{@currentFace.number} in line #{@lineCounter}"
					)
				@last = 'solid'
				continue

			if @last is 'solid'
				if typeof @currentModel.name is 'string'
					@currentModel.name += ' ' + word
				else
					@currentModel.name = word
				continue

		# Make blocking of UI optional (4ms is the minimum value in HTML5)
		if @options.blocking
			done()
		else
			setTimeout done, 4

module.exports = AsciiParser
