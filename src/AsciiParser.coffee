util = require 'util'
EventEmitter = require('events').EventEmitter

Ascii = require './Ascii'
Binary = require './Binary'
Polygon = require './Polygon'
Vector = require './Vector'


class AsciiParser extends EventEmitter
	constructor: (@fileContent) ->
		@asciiStl = new Ascii(@fileContent)

	parse: =>
		model = {
			faces: []
		}
		currentPoly = null

		while !@asciiStl.reachedEnd()
			cmd = @asciiStl
				.nextText()
				.toLowerCase()

			switch cmd
				when 'solid'
					model.name = @asciiStl.nextText()

				when 'facet'
					if (currentPoly?)
						@emit('FacetWarning')
						model.faces.addPolygon currentPoly
						currentPoly = null
					currentPoly = new Polygon()

				when 'endfacet'
					if !(currentPoly?)
						@emit(
							'FacetWarning',
							{message: 'Facet was ended without beginning it!'}
						)
					else
						model.faces.push currentPoly
						currentPoly = null

				when 'normal'
					nx = parseFloat @asciiStl.nextText()
					ny = parseFloat @asciiStl.nextText()
					nz = parseFloat @asciiStl.nextText()

					if (!(nx?) or !(ny?) or !(nz?))
						@emit('NormalWarning')
					else
						if not (currentPoly?)
							@emit(
								'NormalWarning',
								{message: 'Normal definition
											without an existing polygon!'}
							)
							currentPoly = new Polygon()
						currentPoly.setNormal new Vector(nx, ny, nz)

				when 'vertex'
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

		@emit 'end', model


module.exports = AsciiParser
