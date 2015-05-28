stream = require 'stream'


class GenericStream extends stream.Readable
	constructor: (@data, @options = {}) ->
		super @options

	_read: () ->
		@push @data
		@push null


module.exports = GenericStream
