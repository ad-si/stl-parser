fs = require 'fs'
path = require 'path'
chai = require 'chai'
stream = require 'stream'

stlImporter = require '../src/index'
AsciiParser = require '../src/AsciiParser'

chai.use require 'chai-as-promised'
expect = chai.expect

models = [
	'multiWordName'
	'polytopes/triangle'
	'polytopes/tetrahedron'
	'polytopes/cube'
	'broken/fourVertices'
	'broken/twoVertices'
	'broken/wrongNormals'
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


describe 'STL Importer', ->
	it 'Transforms a stl-stream to an jsonl stream', (done) ->

		asciiStlStream = fs.createReadStream(
			modelsMap['polytopes/tetrahedron'].asciiPath
		)
		streamTester = new StreamTester()

		asciiStlStream
			.pipe stlImporter()
			.pipe streamTester

		streamTester.on 'finish', -> done()


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


	it 'should return an array of faces', (done) ->
		asciiStl = fs.readFileSync modelsMap['polytopes/tetrahedron'].asciiPath

		stlImporter asciiStl
			.on 'data', (data) ->
				expect(data).to.be.a.triangleMesh
				done()


	it.skip 'should fix faces with 4 or more vertices', ->
		asciiStl = fs.readFileSync modelsMap['broken/fourVertices'].asciiPath

		promise = stlImporter asciiStl
			.catch (error) -> console.error error

		return expect(promise).to.eventually.be.a.triangleMesh


	it.skip 'should fix faces with 2 or less vertices', ->
		asciiStl = fs.readFileSync modelsMap['broken/twoVertices'].asciiPath

		modelPromise = meshlib asciiStl, {format: 'stl'}
			.fixFaces()
			.done (model) -> model

		return expect(modelPromise).to.eventually.be.a.triangleMesh


	it.skip 'ascii & binary version should have equal faces', () ->
		@timeout('10s')

		asciiStl = fs.readFileSync modelsMap['objects/gearwheel'].asciiPath
		binaryStl = fs.readFileSync modelsMap['objects/gearwheel'].binaryPath

		return Promise
		.all([
				meshlib(asciiStl, {format: 'stl'})
				.done((model) -> model)
			,
				meshlib(binaryStl, {format: 'stl'})
				.done((model) -> model)
			])
		.then (models) =>
			expect(models[0].mesh.faces).to
			.equalFaces(models[1].mesh.faces)
