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
		@options.format ?= 'jsonl'

		super @options

		@debugBuffer = ''
		@internalBuffer = ''
		@last = 'root'
		@currentModel = null
		@currentFace = null

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
					@currentFace.number = ++@countedFaces

				if @last is 'vertex-z' or @last is 'loop'
					if @currentFace.vertices.length >= 3
						@emit 'warning', "Face #{@countedFaces} has 4
								instead of 3 vertices"
					else
						@currentVertex = {
							x: null,
							y: null,
							z: null
						}
						@currentFace.vertices.push @currentVertex
				else
					throw new Error "Unexpected vertex after #{@last}
								in face #{@countedFaces} in line #{@lineCounter}"

				@last = 'vertex'
				continue


			if word is 'facet'
				if @last is 'solid' or @last is 'name'
					if @options.format isnt 'json'
						@push @currentModel
				else if @last isnt 'endfacet'
					throw new Error "Unexpected facet after #{@last}
								in face #{@countedFaces} in line #{@lineCounter}"

				@last = 'facet'
				continue


			if word is 'normal'
				if @last is 'facet'
					@currentFace = {
						normal: {x: null, y: null, z: null}
					}
				else
					throw new Error('Unexpected normal after ' + @last)

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
					throw new Error "Unexpected outer after #{@last}
								in face #{@countedFaces} in line #{@lineCounter}"

			if word is 'loop'
				if @last isnt 'outer'
					throw new Error "Unexpected loop after #{@last}
								in face #{@countedFaces} in line #{@lineCounter}"

				@last = 'loop'
				continue

			if word is 'endloop'
				if @last isnt 'vertex-z'
					throw new Error "Unexpected endloop after #{@last}
								in face #{@countedFaces} in line #{@lineCounter}"

				else if @currentFace.vertices.length <= 2
					@emit 'warning', "Face #{@countedFaces} has
						#{@currentFace.vertices.length} instead of 3 vertices"
					@currentFace = null

				@last = 'endloop'
				continue

			if word is 'endfacet'
				if @last is 'endloop'
					if @currentFace
						if @options.format is 'json'
							@currentModel.faces.push @currentFace
						else
							@push @currentFace
				else
					@emit 'error', new Error "Unexpected endfacet after #{@last}
								in face #{@countedFaces} in line #{@lineCounter}"
				@last = 'endfacet'
				continue

			if word is 'endsolid'
				if @last is 'endfacet'
					if @options.format is 'json'
						@push @currentModel
					@push null
				else
					throw new Error "Unexpected endsolid after #{@last}
								in face #{@countedFaces} in line #{@lineCounter}"

				@last = 'endsolid'
				continue

			if word is 'solid'
				if @last is 'root'
					@currentModel = {name: null}
					if @options.format is 'json'
						@currentModel.faces = []
				else
					throw new Error "Unexpected solid after #{@last}
								in face #{@countedFaces} in line #{@lineCounter}"
				@last = 'solid'
				continue

			if @last is 'name'
				@currentModel.name += ' ' + word
				@last = 'name'
				continue

			if @last is 'solid'
				@currentModel.name = word
				@last = 'name'
				continue

		done()


module.exports = AsciiParser
