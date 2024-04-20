import stream from "stream"

export default class GenericStream extends stream.Readable {
  options: Record<string, any>
  data: any

  constructor(data: any, options: Record<string, any> = {}) {
    super(options)
    this.options = options
    this.data = data
  }

  _read() {
    this.push(this.data)
    return this.push(null)
  }
}
