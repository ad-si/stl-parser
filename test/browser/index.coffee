ReadableFileStream = require('filestream').read

stlImporter = require('../../src/index')

bufferedContainer = document.getElementById('bufferedLoading')
streamedContainer = document.getElementById('streamedLoading')
progressBar = document.querySelector 'progress'

getFinishString = (modelName, fileName, endTime) ->
	return "✔ Loaded model \"#{modelName}\"
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
		stlImporter(event.target.result).on 'data', (data) ->
			bufferedContainer
			.querySelector('p')
			.textContent = getFinishString(
				data.name
				files[0].name
				new Date() - startTime
			)

	reader.readAsArrayBuffer files[0]

loadStreamed = (changeEvent) ->
	changeEvent.preventDefault()
	changeEvent.stopPropagation()

	resetProgressDisplay()

	files = changeEvent.target.files
	checkFilesCount files

	stlParser = stlImporter()
	fileStream = new ReadableFileStream files[0]

	faceCounter = 0
	averageFaceSize = 240 # Byte
	modelName = ''

	stlParser.on 'data', (data) ->
		if not data.number?
			faceCounter =
			if data.faceCount
			then data.faceCount
			else files[0].size / averageFaceSize
			modelName = data.name
		else
			progressBar.setAttribute 'value', String data.number / faceCounter

	stlParser.on 'end', () ->
		progressBar.setAttribute 'value', '1'
		streamedContainer.querySelector('p').textContent = getFinishString(
			modelName
			files[0].name
			new Date() - startTime
		)


	fileStream.on 'error', (error) ->
		throw error

	startTime = new Date()
	fileStream.pipe stlParser


bufferedContainer
.querySelector 'input'
.addEventListener 'change', loadBuffered

streamedContainer
.querySelector 'input'
.addEventListener 'change', loadStreamed
