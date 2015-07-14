assign = Object.assign || require 'object.assign'

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
		@options.writableObjectMode = false
		@options.readableObjectMode = true
		@options.blocking ?= true
		@options.format ?= 'jsonl'
		@options.discardExcessVertices ?= true

		super @options

		@debugBuffer = ''
		@internalBuffer = ''
		@last = 'root'
		@defaultModel = {
			name: null
			type: 'ascii'
			endName: null
			isClosed: false
		}
		@currentModel = assign {}, @defaultModel
		@currentFace = {
			number: 0
		}

		@countedFaces = 0
		@lineCounter = 1
		@characterCounter = 0


	_parseCoordinate: (word, type) =>
		value = null

		try
			value = toNumber word

		catch error
			@emit(
				'warning',
				"Unexpected '#{word}' instead of #{type} value
				in face #{@currentFace.number}, line #{@lineCounter}"
			)

		@last = type
		return value


	getNextWord: () =>
		if /^\s*\n\s*/gi.test @internalBuffer
			@lineCounter++

		whitespace = @internalBuffer.match /^\s+/

		if whitespace
			@characterCounter += whitespace[0].length
			@internalBuffer = @internalBuffer.substr whitespace[0].length

		words = @internalBuffer.match /^\S+/

		if (words is null) or (words[0].length is @internalBuffer.length)
			if @internalBuffer is ''
				@push null
			return null
		else
			@characterCounter += words[0].length
			@internalBuffer = @internalBuffer.substr words[0].length

			if @options.size > 0
				@emit 'progress', @characterCounter / @options.size

			return words[0]

	_processWord: (word) ->

		# If statements are sorted descendingly
		# by relative frequency of the corresponding keyword
		# in STL-files

		if @last is 'vertex'
			@currentVertex.x = @_parseCoordinate word, 'vertex-x'
			return

		if @last is 'vertex-x'
			@currentVertex.y = @_parseCoordinate word, 'vertex-y'
			return

		if @last is 'vertex-y'
			@currentVertex.z = @_parseCoordinate word, 'vertex-z'
			return


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
					'warning',
					"Unexpected vertex after #{@last}
					in face #{@currentFace.number} in line #{@lineCounter}"
				)
			@last = 'vertex'
			return


		if word is 'facet'
			@currentFace = {
				number: @countedFaces + 1
			}
			if @last is 'solid'
				if not @currentModel.name?
					@currentModel.name = ''
					@emit(
						'warning',
						"Solid in line #{@lineCounter - 1}
						does not have a name"
					)
				if @options.format isnt 'json'
					@push {
						name: @currentModel.name,
						type: @currentModel.type
					}

			else if @last isnt 'endfacet'
				@emit(
					'warning',
					"Unexpected facet after #{@last}
					in face #{@currentFace.number} in line #{@lineCounter}"
				)

			@last = 'facet'
			return


		if word is 'normal'
			if @last is 'facet'
				@currentFace.normal = {x: null, y: null, z: null}
			else
				@emit(
					'warning',
					"Unexpected normal after #{@last}"
				)

			@last = 'normal'
			return

		if @last is 'normal'
			@currentFace.normal.x = @_parseCoordinate word, 'normal-x'
			if not @currentFace.normal.x?
				@currentFace.normal.x = 0
				@_processWord word
			return

		if @last is 'normal-x'
			@currentFace.normal.y = @_parseCoordinate word, 'normal-y'
			if not @currentFace.normal.y?
				@currentFace.normal.y = 0
				@_processWord word
			return

		if @last is 'normal-y'
			@currentFace.normal.z = @_parseCoordinate word, 'normal-z'
			if not @currentFace.normal.z?
				@currentFace.normal.z = 0
				@_processWord word
			return

		if word is 'outer'
			if @last is 'normal-z'
				@last = 'outer'
				return
			else
				@emit(
					'warning',
					"Unexpected outer after #{@last}
					in face #{@currentFace.number} in line #{@lineCounter}"
				)

		if word is 'loop'
			if @last isnt 'outer'
				@emit(
					'warning',
					"Unexpected loop after #{@last}
					in face #{@currentFace.number} in line #{@lineCounter}"
				)

			@last = 'loop'
			return

		if word is 'endloop'
			if @last isnt 'vertex-z'
				@emit(
					'warning',
					"Unexpected endloop after #{@last}
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
			return

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
					'warning',
					"Unexpected endfacet after #{@last}
					in face #{@currentFace.number} in line #{@lineCounter}"
				)
			@last = 'endfacet'
			return

		if word is 'endsolid'
			if @options.format is 'json' or @last is 'solid'
				@push {
					name: @currentModel.name
					type: @currentModel.type
					faces: @currentModel.faces
				}

			if @last is 'endfacet' or @last is 'solid'
				@currentModel.isClosed = true
			else
				@emit(
					'warning',
					"Unexpected endsolid after #{@last}
					in face #{@currentFace.number} in line #{@lineCounter}"
				)

			@last = 'endsolid'
			return

		if word is 'solid'
			if @last is 'root' or @last is 'endsolid'
				@currentModel = assign {}, @defaultModel
				@currentFace = {number: 0}
				if @options.format is 'json'
					@currentModel.faces = []
			else
				@emit(
					'warning',
					"Unexpected solid after #{@last}
					in face #{@currentFace.number} in line #{@lineCounter}"
				)
			@last = 'solid'
			return

		if @last is 'solid'
			if typeof @currentModel.name is 'string'
				@currentModel.name += ' ' + word
			else
				@currentModel.name = word
			return

		if @last is 'endsolid'
			if typeof @currentModel.endName is 'string'
				@currentModel.endName += ' ' + word
			else
				@currentModel.endName = word


	_flush: (done) =>
		if not @currentModel.isClosed and
		@countedFaces is 0 and
		@currentModel.name is null and
		@currentModel.endName is null
			@emit(
				'warning',
				'Provided ascii STL should
				probably be parsed as a binary STL'
			)

		if Boolean(@currentModel.endName) isnt Boolean(@currentModel.name)
			@emit 'warning',
				"Solid name (\"#{@currentModel.name.substr(0,50)}\")
				and endsolid name (\"#{@currentModel.endName}\") do not match"

		if @countedFaces is 0
			if @currentModel.name?.length > 50
				@currentModel.name = @currentModel.name.substr(0,50) + '…'
			@emit(
				'warning',
				'Solid ' +
				(if @currentModel.name
				then "'#{@currentModel.name}'"
				else '<no name>') +
				' does not contain any faces'
			)

		if @currentModel.name is null
			return done new Error 'Provided ascii STL contains an invalid solid'

		if not @currentModel.isClosed and @internalBuffer isnt 'endsolid'
			return done new Error 'Provided ascii STL is not
				closed with endsolid keyword'

		@emit 'progress', 1
		done()


	_callAtEnd: (done) ->
		# Make blocking of UI optional (4ms is the minimum value in HTML5)
		if @options.blocking
			done()
		else
			setTimeout done, 4


	_transform: (chunk, encoding, done) =>

		@internalBuffer += chunk.toString()

		while word = @getNextWord()
			@_processWord word

		@_callAtEnd done


module.exports = AsciiParser
