import Vector from "./Vector.ts"

export type ModelsMap = {
  [key: string]: {
    name: string
    asciiPath: string
    binaryPath: string
  }
}

export type Face = {
  normal: Vector
  vertices: Vector[]
  number?: number
  attribute?: number
}

export type Polyhedron = {
  type: "binary" | "ascii"
  faces: Face[]
  name?: string
  faceCount?: number
}

export type ParserOptions = {
  type?: "binary" | "ascii"
  format?: "json" | "jsonl"
  blocking?: boolean
  size?: number
  readableObjectMode?: boolean
  writableObjectMode?: boolean
  discardExcessVertices?: boolean
}
