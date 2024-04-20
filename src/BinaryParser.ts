import stream, { TransformCallback } from "stream"
import bufferTrim from "buffertrim"

import { Face, ParserOptions, Polyhedron } from "./types.ts"
import Vector from "./Vector.ts"

const defaultOptions: ParserOptions = {
  format: "jsonl",
  blocking: true,
  writableObjectMode: false,
  readableObjectMode: true,
}

export default class BinaryParser extends stream.Transform {
  options: ParserOptions
  internalBuffer: Buffer
  header: string
  faceCounter: number
  countedFaces: number
  cursor: number
  currentModel: Polyhedron
  currentFace: Face
  headerByteCount: number
  vertexByteCount: number
  attributeByteCount: number
  facesCounterByteCount: number
  faceByteCount: number
  facesOffset: number
  coordinateByteCount: number

  constructor(options: ParserOptions = defaultOptions) {
    options = { ...defaultOptions, ...options }
    super(options)

    this.options = options
    this._flush = this._flush.bind(this)
    this.internalBuffer = Buffer.alloc(0)
    this.header = ""
    this.faceCounter = 0
    this.countedFaces = 0
    this.cursor = 80
    this.currentModel = {
      type: "binary",
      faces: [],
    }
    this.currentFace = {
      normal: new Vector(0, 0, 0),
      vertices: [],
    }

    // File-structure:
    //
    // | header (80 * UInt8) |
    // | facesCounter (1 * UInt32) |
    //
    // face (50 Byte)
    // | normal (3 * Float) |
    // | vertex 1 (3 * Float) |
    // | vertex 2 (3 * Float) |
    // | vertex 3 (3 * Float) |
    // | attribute 3 (1 * UInt16) |
    //
    // | … |

    this.headerByteCount = 80
    this.vertexByteCount = 12
    this.attributeByteCount = 2
    this.facesCounterByteCount = 4
    this.faceByteCount = 50
    this.facesOffset = this.headerByteCount + this.facesCounterByteCount
    this.coordinateByteCount = 4
  }

  _flush(done: TransformCallback) {
    if (this.countedFaces === 0) {
      this.emit(
        "error", //
        new Error("No faces were specified in the binary STL")
      )
    } //
    else if (this.faceCounter !== this.countedFaces) {
      this.emit(
        "warning",
        `Number of specified faces (${this.faceCounter}) and \
counted number of faces (${this.countedFaces}) do not match`
      )
    }

    if (this.options.format === "json") {
      this.currentModel.type = "binary"
      // console.log("flush", this.currentModel)
      this.push(this.currentModel)
      return done()
    } //
    else {
      return done()
    }
  }

  _transform(chunk: Uint8Array, _encoding: string, done: TransformCallback) {
    this.internalBuffer = Buffer.concat([this.internalBuffer, chunk])

    while (this.cursor <= this.internalBuffer.length) {
      if (this.cursor === this.headerByteCount) {
        this.header = bufferTrim
          .trimEnd(this.internalBuffer.slice(0, this.headerByteCount))
          .toString()
        this.currentModel.name = this.header

        if (this.options.format === "json") {
          this.currentModel.faces = []
        }

        this.cursor += this.facesCounterByteCount
        continue
      }

      if (this.cursor === this.facesOffset) {
        this.faceCounter = this.internalBuffer.readUInt32LE(
          this.headerByteCount
        )

        this.currentModel.faceCount = this.faceCounter

        if (this.options.format !== "json") {
          // console.log("maybe here", this.currentModel)
          this.push(this.currentModel)
        }

        this.cursor += this.faceByteCount
        continue
      }

      if (
        (this.cursor =
          this.facesOffset + (this.countedFaces + 1) * this.faceByteCount)
      ) {
        this.cursor -= this.faceByteCount
        this.currentFace = {
          number: this.countedFaces + 1,
          normal: new Vector(
            this.internalBuffer.readFloatLE(this.cursor),
            this.internalBuffer.readFloatLE(
              (this.cursor += this.coordinateByteCount)
            ),
            this.internalBuffer.readFloatLE(
              (this.cursor += this.coordinateByteCount)
            )
          ),
          vertices: [],
        }

        for (var i = 0; i <= 2; i++) {
          this.currentFace.vertices.push(
            new Vector(
              this.internalBuffer.readFloatLE(
                (this.cursor += this.coordinateByteCount)
              ),
              this.internalBuffer.readFloatLE(
                (this.cursor += this.coordinateByteCount)
              ),
              this.internalBuffer.readFloatLE(
                (this.cursor += this.coordinateByteCount)
              )
            )
          )
        }

        this.currentFace.attribute = this.internalBuffer.readUInt16LE(
          (this.cursor += this.coordinateByteCount)
        )

        this.cursor += this.attributeByteCount

        if (this.options.format === "json") {
          this.currentModel.faces.push(this.currentFace)
        } else {
          // console.log("currentface", this.currentFace)
          this.push(this.currentFace)
        }

        this.cursor += this.faceByteCount
        this.countedFaces++
      }
    }

    // Make blocking of UI optional (4ms is the minimum value in HTML5)
    if (this.options.blocking) {
      return done()
    } else {
      return setTimeout(done, 4)
    }
  }
}
