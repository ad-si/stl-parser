import { expect } from "bun:test"
import Vector from "../src/Vector.ts"
import { Face, Polyhedron } from "../src/types.ts"
import stream from "stream"
import path from "path"

export function expectTriangleMesh(polyhedron: Polyhedron) {
  expect(polyhedron.faces).toBeArray()
  polyhedron.faces.every((face: Face) => {
    expect(face.vertices?.length).toBe(3)
  })
}

export function equalVector(expected: Vector, actual: Vector) {
  let coords: ("x" | "y" | "z")[] = ["x", "y", "z"]
  return coords.every((coordinate) => {
    const expectedCoordinate = expected[coordinate]
    const actualCoordinate = actual[coordinate]

    expect(actualCoordinate).toBeCloseTo(expectedCoordinate, 4)
  })
}

export function equalFace(expected: Face, actual: Face) {
  equalVector(expected.normal, actual.normal)

  return expected.vertices.every((vertex: Vector, vertexIndex: number) =>
    equalVector(vertex, actual.vertices[vertexIndex])
  )
}

export function equalFaces(expected: Face[], actual: Face[]) {
  return expected.forEach((face: Face, faceIndex: number) =>
    equalFace(face, actual[faceIndex])
  )
}

type StreamTesterOptions = {
  objectMode?: boolean
  test?: (chunk?: any) => void
}

const defaultOptions: StreamTesterOptions = {
  objectMode: true,
}

export class StreamTester extends stream.Writable {
  options: Record<string, unknown>
  firstCall: boolean
  secondCall: boolean

  constructor(options: StreamTesterOptions = defaultOptions) {
    options = { ...defaultOptions, ...options }
    super(options)
    this.options = options
    this.firstCall = true
    this.secondCall = true
  }

  _write(
    chunk: {
      type?: string
      name?: string
      faces?: Face[]
      vertices?: Vector[]
      normal?: Vector
      faceCount?: number
    },
    _encoding: string,
    done: () => void
  ) {
    if (typeof this.options.test === "function") {
      this.options.test(chunk)
    }

    // console.log("chunk", chunk)

    if (this.firstCall) {
      expect(typeof chunk).toBe("object")
      expect(chunk).toHaveProperty("type")
      this.firstCall = false
    } //
    else if (this.secondCall) {
      expect(typeof chunk).toBe("object")
      expect(chunk).toHaveProperty("name")
      this.secondCall = false
    } //
    else {
      expect(typeof chunk).toBe("object")
      expect(chunk.vertices).toBeArray()
      expect(chunk).toHaveProperty("normal")
    }

    return done()
  }
}

const __dirname = path.dirname(new URL(import.meta.url).pathname)

export const models = [
  "misc/multiWordName",
  "misc/namelessSolid",

  "polytopes/triangle",
  "polytopes/tetrahedron",
  "polytopes/cube",

  "broken/fourVertices",
  "broken/twoVertices",
  "broken/wrongNormals",
  "broken/wrongHeader",
  "broken/incorrectFaceCounter",
  "broken/solidNameMismatch",
  "broken/missingEndsolid",
  "broken/missingNormal",
  "broken/notANumberNormal",

  "objects/gearwheel",
  "objects/bunny",
].map((model) => ({
  name: model,

  asciiPath: path.resolve(
    __dirname,
    "../node_modules/stl-models/",
    model + ".ascii.stl"
  ),

  binaryPath: path.resolve(
    __dirname,
    "../node_modules/stl-models/",
    model + ".bin.stl"
  ),
}))
