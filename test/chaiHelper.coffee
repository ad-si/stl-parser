maxCoordinateDelta = 0.00001


module.exports = (chai, utils) ->

	chai.Assertion.addProperty 'triangleMesh', () ->

		allTriangles = @_obj.faces.every (face) ->
			return face.vertices.length is 3

		# coffeelint: disable=no_interpolation_in_single_quotes
		@assert(
			allTriangles
			'expected mesh #{this} to consist only of triangles',
			'expected mesh #{this} to not consist only of triangles'
		)
		# coffeelint: enable=no_interpolation_in_single_quotes


	chai.Assertion.addMethod 'equalVector', (vertex) ->
		['x', 'y', 'z'].every (coordinate) =>

			actualCoordinate = @_obj[coordinate]
			expectedCoordinate = vertex[coordinate]

			chai.expect(actualCoordinate).to.be
				.closeTo(expectedCoordinate, maxCoordinateDelta)


	chai.Assertion.addMethod 'equalFace', (face) ->
		chai.expect(@_obj.normal).to.equalVector(face.normal)

		@_obj.vertices.every (vertex, vertexIndex) ->
			chai.expect(vertex).to.equalVector(face.vertices[vertexIndex])


	chai.Assertion.addMethod 'equalFaces', (faces) ->
		@_obj.forEach (face, faceIndex) ->
			chai.expect(face).to.equalFace(faces[faceIndex])
