import stream from "stream"

import toNumber from "./toNumber.ts"
import { ParserOptions } from "./types.ts"

const { Transform } = stream

const defaultParserOptions: ParserOptions = {
  format: "jsonl",
  blocking: true,
  writableObjectMode: false,
  readableObjectMode: true,
  discardExcessVertices: true,
}

const emptyModel = {
  name: null,
  endName: null,
  isClosed: false,
}

const emptyFace = {
  number: 0,
  normal: { x: null, y: null, z: null },
  vertices: [],
}

type NullableVector = {
  x: number | null
  y: number | null
  z: number | null
}

export default class AsciiParser extends Transform {
  options: ParserOptions
  debugBuffer: string
  internalBuffer: string
  last: string
  currentModel: Record<string, any>
  currentFace: {
    number: number
    normal: NullableVector
    vertices: NullableVector[]
  } | null
  countedFaces: number
  lineCounter: number
  characterCounter: number
  currentVertex: NullableVector

  constructor(options: ParserOptions = defaultParserOptions) {
    options = { ...defaultParserOptions, ...options }

    super(options)
    this.options = options

    this._parseCoordinate = this._parseCoordinate.bind(this)
    this.getNextWord = this.getNextWord.bind(this)
    this._flush = this._flush.bind(this)
    this._transform = this._transform.bind(this)

    this.debugBuffer = ""
    this.internalBuffer = ""
    this.last = "root"
    this.currentModel = Object.assign({}, emptyModel)
    this.currentFace = {
      number: 0,
      normal: { x: null, y: null, z: null },
      vertices: [],
    }
    this.currentVertex = { x: null, y: null, z: null }

    this.countedFaces = 0
    this.lineCounter = 1
    this.characterCounter = 0
  }

  _parseCoordinate(word: string, type: string): number | null {
    let value = null

    try {
      value = toNumber(word)
    } catch (error) {
      this.emit(
        "warning",
        `Unexpected '${word}' instead of ${type} value ` +
          `in face ${this.currentFace?.number}, line ${this.lineCounter}`
      )
    }

    this.last = type
    return value
  }

  getNextWord() {
    if (/^\s*\n\s*/gi.test(this.internalBuffer)) {
      this.lineCounter++
    }

    const whitespace = this.internalBuffer.match(/^\s+/)

    if (whitespace) {
      this.characterCounter += whitespace[0].length
      this.internalBuffer = this.internalBuffer.substr(whitespace[0].length)
    }

    const words = this.internalBuffer.match(/^\S+/)

    if (words === null || words[0].length === this.internalBuffer.length) {
      return null
    } //
    else {
      this.characterCounter += words[0].length
      this.internalBuffer = this.internalBuffer.substr(words[0].length)

      if (Number(this.options.size) > 0) {
        this.emit("progress", this.characterCounter / Number(this.options.size))
      }

      return words[0]
    }
  }

  _processWord(word: string) {
    // The `if` statements are sorted descending
    // by relative frequency of the corresponding keyword
    // in STL-files

    if (this.last === "vertex") {
      this.currentVertex.x = this._parseCoordinate(word, "vertex-x")
      return
    }

    if (this.last === "vertex-x") {
      this.currentVertex.y = this._parseCoordinate(word, "vertex-y")
      return
    }

    if (this.last === "vertex-y") {
      this.currentVertex.z = this._parseCoordinate(word, "vertex-z")
      return
    }

    if (word === "vertex") {
      if (this.last === "vertex-z" || this.last === "loop") {
        if (this.last === "loop") {
          this.currentFace ??= emptyFace
          this.currentFace.vertices = []
        }

        this.currentFace?.vertices.push(this.currentVertex)
      } else {
        this.emit(
          "warning",
          `Unexpected vertex after ${this.last} ` +
            `in face ${this.currentFace?.number} in line ${this.lineCounter}`
        )
      }
      this.last = "vertex"
      return
    }

    if (word === "facet") {
      this.currentFace = {
        number: this.countedFaces + 1,
        normal: { x: null, y: null, z: null },
        vertices: [],
      }
      if (this.last === "solid") {
        if (this.currentModel.name == null) {
          this.currentModel.name = ""
          this.emit(
            "warning",
            `Solid in line ${this.lineCounter - 1} ` + `does not have a name`
          )
        }
        if (this.options.format !== "json") {
          this.push({
            name: this.currentModel.name,
          })
        }
      } else if (this.last !== "endfacet") {
        this.emit(
          "warning",
          `Unexpected facet after ${this.last} ` +
            `in face ${this.currentFace.number} in line ${this.lineCounter}`
        )
      }

      this.last = "facet"
      return
    }

    if (word === "normal") {
      if (this.last === "facet") {
        this.currentFace ??= emptyFace
        this.currentFace.normal = { x: null, y: null, z: null }
      } //
      else {
        this.emit("warning", `Unexpected normal after ${this.last}`)
      }

      this.last = "normal"
      return
    }

    if (this.last === "normal") {
      this.currentFace ??= emptyFace
      this.currentFace.normal.x = this._parseCoordinate(word, "normal-x")
      if (this.currentFace.normal.x == null) {
        this.currentFace.normal.x = 0
        this._processWord(word)
      }
      return
    }

    if (this.last === "normal-x") {
      this.currentFace ??= emptyFace
      this.currentFace.normal.y = this._parseCoordinate(word, "normal-y")
      if (this.currentFace.normal.y == null) {
        this.currentFace.normal.y = 0
        this._processWord(word)
      }
      return
    }

    if (this.last === "normal-y") {
      this.currentFace ??= emptyFace
      this.currentFace.normal.z = this._parseCoordinate(word, "normal-z")
      if (this.currentFace.normal.z == null) {
        this.currentFace.normal.z = 0
        this._processWord(word)
      }
      return
    }

    if (word === "outer") {
      if (this.last === "normal-z") {
        this.last = "outer"
        return
      } else {
        this.emit(
          "warning",
          `Unexpected outer after ${this.last} ` +
            `in face ${this.currentFace?.number} in line ${this.lineCounter}`
        )
      }
    }

    if (word === "loop") {
      if (this.last !== "outer") {
        this.emit(
          "warning",
          `Unexpected loop after ${this.last} ` +
            `in face ${this.currentFace?.number} in line ${this.lineCounter}`
        )
      }

      this.last = "loop"
      return
    }

    if (word === "endloop") {
      if (this.last !== "vertex-z") {
        this.emit(
          "warning",
          `Unexpected endloop after ${this.last} ` +
            `in face ${this.currentFace?.number} in line ${this.lineCounter}`
        )
      } else if (this.currentFace?.vertices.length !== 3) {
        this.emit(
          "warning",
          `Face ${this.currentFace?.number} has ` +
            `${this.currentFace?.vertices.length} instead of 3 vertices`
        )

        if ((this.currentFace?.vertices?.length || 0) > 3) {
          if (this.options.discardExcessVertices) {
            this.currentFace?.vertices.splice(3)
          }
        } else {
          this.currentFace = null
        }
      }

      this.last = "endloop"
      return
    }

    if (word === "endfacet") {
      if (this.last === "endloop") {
        if (this.currentFace && this.currentFace.vertices) {
          this.countedFaces++
          if (this.options.format === "json") {
            this.currentModel.faces.push(this.currentFace)
          } else {
            this.push(this.currentFace)
          }
        }
      } else {
        this.emit(
          "warning",
          `Unexpected endfacet after ${this.last} ` +
            `in face ${this.currentFace?.number} in line ${this.lineCounter}`
        )
      }
      this.last = "endfacet"
      return
    }

    if (word === "endsolid") {
      if (this.options.format === "json" || this.last === "solid") {
        this.push({
          name: this.currentModel.name,
          type: "ascii",
          faces: this.currentModel.faces,
        })
      }

      if (this.last === "endfacet" || this.last === "solid") {
        this.currentModel.isClosed = true
      } else {
        this.emit(
          "warning",
          `Unexpected endsolid after ${this.last} ` +
            `in face ${this.currentFace?.number} in line ${this.lineCounter}`
        )
      }

      this.last = "endsolid"
      return
    }

    if (word === "solid") {
      if (this.last === "root" || this.last === "endsolid") {
        this.currentModel = Object.assign({}, emptyModel)
        this.currentFace ??= emptyFace
        if (this.options.format === "json") {
          this.currentModel.faces = []
        }
      } else {
        this.emit(
          "warning",
          `Unexpected solid after ${this.last} ` +
            `in face ${this.currentFace?.number} in line ${this.lineCounter}`
        )
      }
      this.last = "solid"
      return
    }

    if (this.last === "solid") {
      if (typeof this.currentModel.name === "string") {
        this.currentModel.name += " " + word
      } else {
        this.currentModel.name = word
      }
      return
    }

    if (this.last === "endsolid") {
      if (typeof this.currentModel.endName === "string") {
        return (this.currentModel.endName += " " + word)
      } else {
        return (this.currentModel.endName = word)
      }
    }
  }

  _flush(done: (err?: Error) => void) {
    // console.log("flush")
    if (
      !this.currentModel.isClosed &&
      this.countedFaces === 0 &&
      this.currentModel.name === null &&
      this.currentModel.endName === null
    ) {
      this.emit(
        "warning",
        `Provided ascii STL should probably be parsed as a binary STL`
      )
    }

    if (
      Boolean(this.currentModel.endName) !== //
      Boolean(this.currentModel.name)
    ) {
      this.emit(
        "warning",
        `Solid name (\"${this.currentModel.name.substr(0, 50)}\") ` +
          `and endsolid name (\"${this.currentModel.endName}\") do not match`
      )
    }

    if (this.countedFaces === 0) {
      if (
        (this.currentModel.name != null
          ? this.currentModel.name.length
          : undefined) > 50
      ) {
        this.currentModel.name = this.currentModel.name.substr(0, 50) + "…"
      }
      this.emit(
        "warning",
        "Solid " +
          (this.currentModel.name
            ? `'${this.currentModel.name}'`
            : "<no name>") +
          " does not contain any faces"
      )
    }

    if (this.currentModel.name === null) {
      return done(new Error("Provided ascii STL contains an invalid solid"))
    }

    if (!this.currentModel.isClosed && this.internalBuffer !== "endsolid") {
      return done(
        new Error(`Provided ascii STL is not \
closed with endsolid keyword`)
      )
    }

    this.emit("progress", 1)
    return done()
  }

  _callAtEnd(done: () => void) {
    // Make blocking of UI optional (4ms is the minimum value in HTML5)
    if (this.options.blocking) {
      return done()
    } //
    else {
      return setTimeout(done, 4)
    }
  }

  _transform(chunk: any, _encoding: string, done: (err?: Error) => void) {
    let word
    this.internalBuffer += chunk.toString()

    while ((word = this.getNextWord())) {
      this._processWord(word)
    }

    return this._callAtEnd(done)
  }
}
