ReadableFileStream = require('filestream').read

stlImporter = require('../../src/index')

bufferedContainer = document.getElementById('bufferedLoading')
streamedContainer = document.getElementById('streamedLoading')
progressBar = document.querySelector 'progress'


resetProgressDisplay = () ->
	streamedContainer.querySelector('p').textContent = ''
	progressBar.setAttribute 'value', '0'

loadBuffered = (changeEvent) ->
	files = changeEvent.target.files
	filesArray = new Array(files)
	reader = new FileReader
	reader.addEventListener 'load', (file) ->
		stlImporter(file.target.result).on 'data', (data) ->
			console.log 'Loaded', data
			bufferedContainer.querySelector('p').textContent =
				'Loaded "' + data.name + '"'

	filesArray.forEach (file, index) ->
		reader.readAsArrayBuffer files[index]

loadStreamed = (changeEvent) ->
	changeEvent.preventDefault()
	changeEvent.stopPropagation()

	resetProgressDisplay()

	files = changeEvent.target.files
	stlParser = stlImporter()
	fileStream = new ReadableFileStream files[0]

	faceCounter = 0
	averageFaceSize = 240 # Byte

	stlParser.on 'data', (data) ->

		if not data.number?
			if data.faceCount
				faceCounter = data.faceCount
			else
				faceCounter = files[0].size / averageFaceSize
		else
			progressBar.setAttribute 'value', String data.number / faceCounter


	stlParser.on 'end', () ->
		progressBar.setAttribute 'value', '1'
		streamedContainer.querySelector('p').textContent = '✔'


	fileStream.on 'error', (error) ->
		throw error

	fileStream.pipe stlParser


bufferedContainer
.querySelector 'input'
.addEventListener 'change', loadBuffered

streamedContainer
.querySelector 'input'
.addEventListener 'change', loadStreamed
