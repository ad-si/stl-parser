var ReadableFileStream = require('filestream').read,

	//ReadableFileStream = require('filereader-stream'),

	stlImporter = require('../../src/index'),

	bufferedContainer = document.getElementById('bufferedLoading'),
	streamedContainer = document.getElementById('streamedLoading')


function loadBuffered (changeEvent) {

	var files = changeEvent.target.files,
		filesArray = new Array(files),
		reader = new FileReader()

	reader.addEventListener('load', function (file) {

		stlImporter(file.target.result)
			.on('data', function (data) {
				console.log('Loaded', data)
				bufferedContainer
					.querySelector('p')
					.textContent = 'Loaded "' + data.name + '"'
			})
	})

	filesArray.forEach(function (file, index) {
		reader.readAsArrayBuffer(files[index])
	})
}

function loadStreamed (changeEvent) {

	var files = changeEvent.target.files,
		progress = document.querySelector('progress'),
		stlParser = stlImporter(),
		fileStream = new ReadableFileStream(files[0]),
		counter = 0


	stlParser.on('data', function (data) {

		counter++

		if (counter % 1000 === 1)
			streamedContainer
				.querySelector('p')
				.textContent = 'Face "' + data.number + '"'
	})

	fileStream.reader.addEventListener('progress', function (event) {

		var percentageLoaded = 0

		if (event.lengthComputable) {
			percentageLoaded = (event.loaded / event.total).toFixed(2)

			progress.setAttribute('value', percentageLoaded)
		}
	})

	fileStream.on('error', function (error) {
		throw error
	})

	fileStream.pipe(stlParser)
}


bufferedContainer
	.querySelector('input')
	.addEventListener('change', loadBuffered)

streamedContainer
	.querySelector('input')
	.addEventListener('change', loadStreamed)
