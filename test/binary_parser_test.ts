import fs from "fs"
import { test, expect, describe } from "bun:test"

import stlParser from "../src/index.ts"
import { Face, ModelsMap, Polyhedron } from "../src/types.ts"
import { StreamTester, expectTriangleMesh, models } from "./helper.ts"

const modelsMap = models.reduce((previous, current, index) => {
  previous[current.name] = models[index]
  return previous
}, {} as ModelsMap)

describe("Binary Parser", () => {
  test("Transforms stl-stream to jsonl stream", (done: () => void) => {
    const model = modelsMap["polytopes/tetrahedron"]
    const binaryStlStream = fs.createReadStream(model.binaryPath)

    const binaryStreamTester = new StreamTester()
    binaryStreamTester.on("finish", () => done())
    return binaryStlStream.pipe(stlParser()).pipe(binaryStreamTester)
  })

  test("Returns an array of faces", (done: () => void) => {
    const model = modelsMap["polytopes/tetrahedron"]
    const binaryStl = fs.readFileSync(model.binaryPath)

    return stlParser(binaryStl, { format: "json" }).on(
      "data",
      (polyhedron: Polyhedron) => {
        expectTriangleMesh(polyhedron)
        return done()
      }
    )
  })

  test("Emits warning if faceCounter and number of faces do not match", (done: () => void) => {
    const model = modelsMap["broken/incorrectFaceCounter"]
    const binaryStl = fs.readFileSync(model.binaryPath)

    return stlParser(binaryStl)
      .on("warning", (warning: string) =>
        expect(warning).toBe(
          "Number of specified faces (66) " +
            "and counted number of faces (4) do not match"
        )
      )
      .on("data", (data: any) => done())
  })

  return test(//
  'Emit a header with a field "type" set to "binary"', (done: () => void) => {
    const binaryStl = fs.readFileSync(
      modelsMap["polytopes/tetrahedron"].binaryPath
    )

    return stlParser(binaryStl).on(
      "data",
      function (data: { type: string; faces: Face[] }) {
        if (Array.isArray(data.faces)) {
          expect(data.type).toBe("binary")
        }
        return done()
      }
    )
  })
})
