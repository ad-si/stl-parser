var stlImporter = require('../../src/index'),
	reader = new FileReader()


function handleFileSelect (events) {

	var files = events.target.files,
		filesArray = Array(files)

	filesArray.forEach(function (file, index) {
		reader.readAsArrayBuffer(files[index])
	})
}

reader.addEventListener('load', function (file) {

	console.log(file)
	stlImporter(file.target.result)
		.on('data', function (data) {
			console.log('test', data)
		})
})

document
	.getElementById('filesInput')
	.addEventListener('change', handleFileSelect, false)

