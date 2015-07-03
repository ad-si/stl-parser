fs = require 'fs'
path = require 'path'
util = require 'util'
chai = require 'chai'
stream = require 'stream'
os = require 'os'
childProcess = require 'child_process'

stlParser = require '../src/index'
AsciiParser = require '../src/AsciiParser'

chai.use require './chaiHelper'
expect = chai.expect

models = [
	'misc/multiWordName'
	'polytopes/triangle'
	'polytopes/tetrahedron'
	'polytopes/cube'

	'broken/fourVertices'
	'broken/twoVertices'
	'broken/wrongNormals'
	'broken/incorrectFaceCounter'
	'broken/solidNameMismatch'

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



describe 'Ascii Parser', ->
	it 'Transforms stl-stream to jsonl stream', (done) ->

		model = modelsMap['polytopes/tetrahedron']
		asciiStlStream = fs.createReadStream model.asciiPath

		asciiStreamTester = new StreamTester()
		asciiStreamTester.on 'finish', -> done()
		asciiStlStream
			.pipe stlParser()
			.pipe asciiStreamTester


	it 'Returns an array of faces', (done) ->
		asciiStl = fs.readFileSync modelsMap['polytopes/tetrahedron'].asciiPath

		stlParser asciiStl
		.on 'data', (data) ->
			expect(data).to.be.a.triangleMesh
			done()


	it 'Handles stl-files with multi-word names', (done) ->
		asciiStlStream = fs.createReadStream(
			modelsMap['misc/multiWordName'].asciiPath
		)
		streamTester = new StreamTester {
			testFirst: (chunk) ->
				expect(chunk?.name).to.equal 'Model with a multi word name'
		}

		asciiStlStream
			.pipe stlParser()
			.pipe streamTester

		streamTester.on 'finish', done


	it 'Emits a warning at mismatching solid and endsolid names', (done) ->
		asciiStlStream = fs.createReadStream(
			modelsMap['broken/solidNameMismatch'].asciiPath
		)
		streamTester = new StreamTester {
			testFirst: (chunk) ->
				expect(chunk?.name).to.equal 'tetrahedron'
		}

		parser = stlParser()
		parser.on 'warning', (warning) ->
			expect(warning).to.equal('Solid and endsolid name do not match')

		asciiStlStream
			.pipe parser
			.pipe streamTester

		streamTester.on 'finish', done


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


	it 'Fixes faces with 4 or more vertices and emits a warning', (done) ->
		asciiStl = fs.readFileSync modelsMap['broken/fourVertices'].asciiPath

		stlParser asciiStl
		.on 'warning', (warning) ->
			expect(warning).to.equal('Face 1 has 4 instead of 3 vertices')

		.on 'data', (data) ->
			expect(data).to.be.a.triangleMesh
			done()


	it 'Fixes faces with 2 or less vertices and emits a warning', (done) ->
		asciiStl = fs.readFileSync modelsMap['broken/twoVertices'].asciiPath

		stlParser asciiStl
		.on 'warning', (warning) ->
			expect(warning).to.equal('Face 1 has 2 instead of 3 vertices')

		.on 'data', (data) ->
			expect(data).to.be.a.triangleMesh
			done()


	it 'Emits progress events', (done) ->
		filePath = modelsMap['polytopes/cube'].asciiPath
		fileStats = fs.statSync filePath
		asciiStlStream = fs.createReadStream filePath
		streamTester = new StreamTester()
		numberOfProgressEvents = 0

		parser = stlParser {size: fileStats.size}
		parser.on 'progress', (progress) ->
			expect(progress).to.be.within 0, 1
			numberOfProgressEvents++

		asciiStlStream
			.pipe parser
			.pipe streamTester

		streamTester.on 'finish', ->
			expect(numberOfProgressEvents).to.equal 257
			done()


describe 'Binary Parser', ->
	it 'Transforms stl-stream to jsonl stream', (done) ->

		model = modelsMap['polytopes/tetrahedron']
		binaryStlStream = fs.createReadStream model.binaryPath

		binaryStreamTester = new StreamTester()
		binaryStreamTester.on 'finish', -> done()
		binaryStlStream
			.pipe stlParser()
			.pipe binaryStreamTester


	it 'Returns an array of faces', (done) ->
		model = modelsMap['polytopes/tetrahedron']
		binaryStl = fs.readFileSync model.binaryPath

		stlParser binaryStl
			.on 'data', (data) ->
				expect(data).to.be.a.triangleMesh
				done()


	it 'Emits a warning if faceCounter and
	  number of faces do not match', (done) ->

		model = modelsMap['broken/incorrectFaceCounter']
		binaryStl = fs.readFileSync model.binaryPath

		stlParser binaryStl
			.on 'warning', (warning) ->
				expect(warning).to.equal(
					'Number of specified faces (66) and
					counted number of faces (4) do not match'
				)
			.on 'data', (data) ->
				done()


describe 'STL Parser', ->
	it 'Ascii & binary stl have equal faces (maximum delta: 0.00001)', (done) ->

		@timeout '3s'

		asciiStl = fs.readFileSync modelsMap['objects/gearwheel'].asciiPath
		binaryStl = fs.readFileSync modelsMap['objects/gearwheel'].binaryPath

		stlParser(asciiStl).on 'data', (asciiData) ->
			stlParser(binaryStl).on 'data', (binaryData) ->
				expect(asciiData.faces).to.equalFaces(binaryData.faces)
				done()


unless /^win/.test os.platform
	describe 'CLI', ->
		it 'Parses an ascii-stl file-stream', (done) ->
			filePath = modelsMap['polytopes/cube'].asciiPath

			childProcess.exec(
				"cat #{filePath} | #{__dirname + path.sep}cli.coffee",
				(error, stdout, stderr) ->
					if error then done error
					if stderr then done stderr
					expect(stdout.length).to.equal 1476
					done()
			)


		it 'Parses an binary-stl file-stream', (done) ->
			filePath = modelsMap['polytopes/cube'].binaryPath

			childProcess.exec(
				"cat #{filePath} | #{__dirname + path.sep}cli.coffee",
				(error, stdout, stderr) ->
					if error then done error
					if stderr then done stderr
					expect(stdout.length).to.equal 1641
					done()
			)
