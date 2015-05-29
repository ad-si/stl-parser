# STL Parser

STL-parser is a transform stream which convert STL-files to newline separated
JSON events for each face.
Check out [jsonlines.org](http://jsonlines.org) for a detailed specification
of the jsonl format.


## Installation

As a module for your project:

```sh
npm install stl-parser
```

As a command line program:

```sh
npm install -g stl-parser
```


## Usage

### Command Line Interface


```sh
cat test.stl | stl-parser
```

This emits a jsonl file-stream with header and facet events.
The cli flags `--ascii` and `--binary` can be used to enforce
parsing with the specified file-encoding.


### Javascript API

```js
var stlParser = require('stl-parser'),
	stlStream = fs.createReadStream('/path/to/stl/file.stl'),
	outputFile = fs.createWriteStream('/path/to/export/file.jsonl')

stlStream
	.pipe(stlParser())
	.pipe(outputFile)
```


There is also the possibility to use it buffered and get one javascript object
for the whole STL.
This should, however, only be used for small files.

```js
var stlParser = require('stl-parser'),
	stl = fs.readFileSync('/path/to/stl/file.stl')

stlParser(stl).on('data', (data) =>
	fs.writeFileSync('/path/to/export/file.json', data)
)
```
