import stream from "stream"
import clone from "clone"

import AsciiParser from "./AsciiParser.ts"
import BinaryParser from "./BinaryParser.ts"
import { ParserOptions, Polyhedron } from "./types.ts"

const defaultOptions: ParserOptions = {
  format: "jsonl",
  blocking: true,
  writableObjectMode: false,
  readableObjectMode: true,
}

export default class StlParser extends stream.Transform {
  options: ParserOptions
  firstCall: boolean
  parser: AsciiParser | BinaryParser

  constructor(options: ParserOptions = defaultOptions) {
    options = { ...defaultOptions, ...options }
    super(options)
    this.options = options
    this.firstCall = true
    this.parser = new AsciiParser(this.options)
  }

  _flush(done: () => void) {
    if (this.parser) {
      this.parser.end()
    } else {
      this.emit("error", new Error("Provided STL-string must not be empty"))
    }

    return done()
  }

  _transform(chunk: {}, _encoding: string, done: () => void) {
    if (this.firstCall) {
      this.firstCall = false

      const isAsciiModel =
        this.options.type === "ascii" || //
        chunk.toString().startsWith("solid")

      if (isAsciiModel) {
        if (this.options.format === "jsonl") {
          this.push(
            this.options.readableObjectMode
              ? { type: "ascii" }
              : JSON.stringify({ type: "ascii" }) + "\n"
          )
        }
      } //
      else {
        this.parser = new BinaryParser(clone(this.options))
        if (this.options.format === "jsonl") {
          this.push(
            this.options.readableObjectMode
              ? { type: "binary" }
              : JSON.stringify({ type: "binary" }) + "\n"
          )
        }
      }

      this.parser.on("data", (data: Polyhedron) => {
        if (this.options.readableObjectMode) {
          return this.push(data)
        } else {
          return this.push(JSON.stringify(data) + "\n")
        }
      })

      this.parser.on("end", () => {
        return this.push(null)
      })

      this.parser.on("error", (error: string) => {
        return this.emit("error", error)
      })

      this.parser.on("warning", (warning: string) => {
        return this.emit("warning", warning)
      })

      this.parser.on("progress", (progress: string) => {
        return this.emit("progress", progress)
      })
    }

    // console.log(this.parser)

    return this.parser.write(chunk, () => done())
  }
}
