fs = require 'fs'
path = require 'path'
util = require 'util'
chai = require 'chai'
stream = require 'stream'

stlImporter = require '../src/index'
AsciiParser = require '../src/AsciiParser'

chai.use require './chaiHelper'
expect = chai.expect

models = [
	'multiWordName'
	'polytopes/triangle'
	'polytopes/tetrahedron'
	'polytopes/cube'

	'broken/fourVertices'
	'broken/twoVertices'
	'broken/wrongNormals'
	'broken/incorrectFaceCounter'

	'objects/gearwheel'
	'objects/bunny'
].map (model) ->
	return {
		name: model
		asciiPath: path.resolve(
			__dirname, '../node_modules/stl-models/', model + '.ascii.stl'
		)
		binaryPath: path.resolve(
			__dirname, '../node_modules/stl-models/', model + '.bin.stl'
		)
	}

modelsMap = models.reduce (previous, current, index) ->
	previous[current.name] = models[index]
	return previous
, {}


class StreamTester extends stream.Writable
	constructor: (@options = {}) ->
		@firstCall = true
		@options.objectMode = true
		super @options

	_write: (chunk, encoding, done) ->

		if @options.test
			@options.test(chunk)

		if @options.testFirst and @firstCall is true
			@options.testFirst(chunk)
			@firstCall = false

		else
			if @firstCall
				expect(chunk)
					.to.be.an('object')
					.and.to.have.ownProperty('name')
				@firstCall = false
			else
				expect(chunk)
					.to.be.a('object')
					.and.to.contain.all.keys(['vertices', 'normal'])
		done()



describe 'AsciiParser', ->
	it 'Gets next word from internal buffer', () ->

		asciiParser = new AsciiParser
		asciiParser.internalBuffer = 'this is a test string'

		expect(asciiParser.getNextWord()).to.equal 'this'


	it 'Counts newlines surrounded by whitespace', () ->

		asciiParser = new AsciiParser
		asciiParser.internalBuffer = 'this is \n a test \n string'

		while asciiParser.getNextWord()
			### empty body ###

		expect(asciiParser.lineCounter).to.equal(3)


	it 'Counts newlines surrounded by words', () ->

		asciiParser = new AsciiParser
		asciiParser.internalBuffer = 'this is\na test\nstring'

		while asciiParser.getNextWord()
			### empty body ###

		expect(asciiParser.lineCounter).to.equal(3)


describe 'BinaryParser', ->

	it 'Emits a warning if faceCounter and
	  number of faces do not match', (done) ->

		model = modelsMap['broken/incorrectFaceCounter']
		binaryStl = fs.readFileSync model.binaryPath

		stlImporter binaryStl
			.on 'warning', (warning) ->
				expect(warning).to.equal(
					'Number of specified faces (66) and
					counted number of faces (4) do not match'
				)
			.on 'data', (data) ->
				done()




describe 'STL Importer', ->

	it 'Transforms ascii stl-stream to jsonl stream', (done) ->

		model = modelsMap['polytopes/tetrahedron']
		asciiStlStream = fs.createReadStream model.asciiPath

		asciiStreamTester = new StreamTester()
		asciiStreamTester.on 'finish', -> done()
		asciiStlStream
			.pipe stlImporter()
			.pipe asciiStreamTester


	it 'Transforms binary stl-stream to jsonl stream', (done) ->

		model = modelsMap['polytopes/tetrahedron']
		binaryStlStream = fs.createReadStream model.binaryPath

		binaryStreamTester = new StreamTester()
		binaryStreamTester.on 'finish', -> done()
		binaryStlStream
			.pipe stlImporter()
			.pipe binaryStreamTester


	it 'Handles STL-files with multi-word names', (done) ->
		asciiStlStream = fs.createReadStream(
			modelsMap['multiWordName'].asciiPath
		)
		streamTester = new StreamTester {
			testFirst: (chunk) ->
				expect(chunk?.name).to.equal 'Model with a multi word name'
		}

		asciiStlStream
			.pipe stlImporter()
			.pipe streamTester

		streamTester.on 'finish', -> done()


	it 'Returns an array of faces', (done) ->
		asciiStl = fs.readFileSync modelsMap['polytopes/tetrahedron'].asciiPath

		stlImporter asciiStl
			.on 'data', (data) ->
				expect(data).to.be.a.triangleMesh
				done()


	it 'Fixes faces with 4 or more vertices and emits a warning', (done) ->
		asciiStl = fs.readFileSync modelsMap['broken/fourVertices'].asciiPath

		stlImporter asciiStl
			.on 'warning', (warning) ->
				expect(warning).to.equal('Face 1 has 4 instead of 3 vertices')

			.on 'data', (data) ->
				expect(data).to.be.a.triangleMesh
				done()


	it 'Fixes faces with 2 or less vertices and emits a warning', (done) ->
		asciiStl = fs.readFileSync modelsMap['broken/twoVertices'].asciiPath

		stlImporter asciiStl
			.on 'warning', (warning) ->
				expect(warning).to.equal('Face 1 has 2 instead of 3 vertices')

			.on 'data', (data) ->
				expect(data).to.be.a.triangleMesh
				done()


	it 'Ascii & binary stl have equal faces (maximum delta: 0.00001)', (done) ->

		@timeout '3s'

		asciiStl = fs.readFileSync modelsMap['objects/gearwheel'].asciiPath
		binaryStl = fs.readFileSync modelsMap['objects/gearwheel'].binaryPath

		stlImporter(asciiStl).on 'data', (asciiData) ->
			stlImporter(binaryStl).on 'data', (binaryData) ->
				expect(asciiData.faces).to.equalFaces(binaryData.faces)
				done()
