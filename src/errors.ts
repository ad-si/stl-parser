let scope
const errors = {
  FacetError(message) {
    const tmp = Error.apply(this, arguments)
    tmp.name = this.name = "FacetError"

    this.stack = tmp.stack
    return (this.message = tmp.message || "Previous facet was not completed!")
  },

  FileError(message, calcDataLength, dataLength) {
    const tmp = Error.apply(this, arguments)
    tmp.name = this.name = "FileError"

    this.stack = tmp.stack
    return (this.message =
      tmp.message ||
      `Calculated length of ${calcDataLength} \
does not match specified file-size of ${dataLength}. \
Triangles might be missing!`)
  },

  NormalError(message, calcDataLength, dataLength) {
    const tmp = Error.apply(this, arguments)
    tmp.name = this.name = "NormalError"

    this.stack = tmp.stack
    return (this.message =
      tmp.message ||
      `Invalid normal definition: \
(${nx}, ${ny}, ${nz})`)
  },

  VertexError(message, calcDataLength, dataLength) {
    const tmp = Error.apply(this, arguments)
    tmp.name = this.name = "VertexError"

    this.stack = tmp.stack
    return (this.message =
      tmp.message ||
      `Invalid vertex definition: \
(${nx}, ${ny}, ${nz})`)
  },
}

if (global) {
  scope = global
} else if (typeof global === "undefined" && window) {
  scope = window
}

for (var errorName in errors) {
  var errorBody = errors[errorName]
  ;(function () {
    scope[errorName] = errorBody

    const Inheritor = () => ({})
    Inheritor.prototype = Error.prototype
    return (scope[errorName].prototype = new Inheritor())
  })()
}
