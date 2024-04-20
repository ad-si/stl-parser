import GenericStream from "./GenericStream.ts"
import StlParser from "./StlParser.ts"
import { ParserOptions } from "./types.ts"

function toBuffer(arrayBuffer: ArrayBuffer | Buffer) {
  if (Buffer.isBuffer(arrayBuffer)) {
    return arrayBuffer
  } //
  else {
    const buffer = Buffer.alloc(arrayBuffer.byteLength)
    const view = new Uint8Array(arrayBuffer)
    let i = 0

    while (i < buffer.length) {
      buffer[i] = view[i]
      ++i
    }

    return buffer
  }
}

function containsKeywords(stlString: string) {
  return (
    stlString.startsWith("solid") &&
    stlString.includes("facet") &&
    stlString.includes("vertex")
  )
}

const defaultParserOptions: ParserOptions = {
  format: "jsonl",
  blocking: true,
  writableObjectMode: false,
  readableObjectMode: true,
}

export default function stlParser(
  fileContent?: string | ArrayBuffer | Buffer | ParserOptions,
  options: ParserOptions = defaultParserOptions
) {
  if (
    typeof fileContent === "undefined" || // Content comes from a stream
    (typeof fileContent === "object" && // `fileContent` is options object
      !Buffer.isBuffer(fileContent) &&
      !(fileContent instanceof ArrayBuffer))
  ) {
    return new StlParser({ ...defaultParserOptions, ...fileContent })
  }

  options = { ...defaultParserOptions, ...options }

  if (typeof fileContent === "string") {
    options.type === "ascii"
  }

  if (options.type === "ascii") {
    if (fileContent === "") {
      throw new Error("Provided STL-string must not be empty")
    } //
    else if (typeof fileContent === "string" && containsKeywords(fileContent)) {
      return new GenericStream(fileContent).pipe(new StlParser(options))
    } else {
      throw new Error("STL string does not contain all stl-keywords!")
    }
  }

  if (options.type === "binary") {
    return new GenericStream(fileContent).pipe(new StlParser(options))
  }

  // Type is not known yet, so try to parse it as ASCII first

  let stlString: string

  if (Buffer.isBuffer(fileContent)) {
    stlString = fileContent.toString()
  } //
  else if (fileContent instanceof ArrayBuffer) {
    fileContent = toBuffer(fileContent)
    stlString = fileContent.toString()
  } //
  else {
    throw new Error(fileContent + " has an unsupported format!")
  }

  if (containsKeywords(stlString)) {
    options.type = "ascii"
    return new GenericStream(stlString).pipe(new StlParser(options))
  }

  // If it couldn't be parsed as ASCII, finally try to parse it as binary
  options.type = "binary"
  return new GenericStream(fileContent).pipe(new StlParser(options))
}
