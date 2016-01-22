ReadableFileStream = require('filestream').read

stlParser = require('../../src/index')

bufferedContainer = document.getElementById('bufferedLoading')
streamedContainer = document.getElementById('streamedLoading')
progressBar = document.querySelector 'progress'

getFinishString = (modelName, fileName, endTime) ->
	return "✔ Parsed and loaded model \"#{modelName}\"
	from file \"#{fileName}\"
	in #{endTime} ms"

checkFilesCount = (files) ->
	if files.length > 1
		warning = 'Multiple files are not yet supported!'
		alert(warning)
		throw new Error(warning)



resetProgressDisplay = () ->
	streamedContainer.querySelector('p').textContent = ''
	progressBar.setAttribute 'value', '0'

loadBuffered = (changeEvent) ->
	files = changeEvent.target.files
	checkFilesCount files

	startTime = new Date()

	reader = new FileReader

	reader.addEventListener 'load', (event) ->
		bufferedContainer
		.querySelector('p')
		.textContent = "✔ Loaded file #{files[0].name}
			in #{new Date() - startTime} ms"

		parse = () ->
			stlParser(event.target.result).on 'data', (data) ->
				bufferedContainer
				.querySelector('p')
				.textContent = getFinishString(
					data.name
					files[0].name
					new Date() - startTime
				)

		setTimeout parse

	reader.readAsArrayBuffer files[0]

loadStreamed = (changeEvent) ->
	changeEvent.preventDefault()
	changeEvent.stopPropagation()

	resetProgressDisplay()

	files = changeEvent.target.files
	checkFilesCount files

	faceCounter = 0
	averageFaceSize = 240 # Byte
	modelName = ''

	fileStream = new ReadableFileStream files[0]
	fileStream.on 'error', (error) ->
		throw error

	streamingStlParser = stlParser {blocking: false}
	streamingStlParser.on 'data', (data) ->
		if not data.number?
			faceCounter =
			if data.faceCount
			then data.faceCount
			else files[0].size / averageFaceSize
			modelName = data.name
		else
			progressBar.setAttribute 'value', String data.number / faceCounter

	streamingStlParser.on 'end', () ->
		progressBar.setAttribute 'value', '1'
		streamedContainer.querySelector('p').textContent = getFinishString(
			modelName
			files[0].name
			new Date() - startTime
		)

	streamingStlParser.on 'warning', console.error
	streamingStlParser.on 'error', console.error

	startTime = new Date()
	fileStream.pipe streamingStlParser


bufferedContainer
.querySelector 'input'
.addEventListener 'change', loadBuffered

streamedContainer
.querySelector 'input'
.addEventListener 'change', loadStreamed
