module.exports = (string) ->
	if not (isNaN parseFloat string)
		return Number string
	else
		throw new Error "'#{string}' isn't a number"
