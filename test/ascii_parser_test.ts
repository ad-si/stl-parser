import fs from "fs"
import path from "path"

import { test, expect, describe } from "bun:test"
import stlParser from "../src/index.ts"
import AsciiParser from "../src/AsciiParser.ts"
import { StreamTester, expectTriangleMesh, models } from "./helper.ts"
import { ModelsMap, Polyhedron } from "../src/types.ts"

const modelsMap = models.reduce((previous, current, index) => {
  previous[current.name] = models[index]
  return previous
}, {} as ModelsMap)

describe("Ascii Parser", () => {
  test("Transforms stl-stream to jsonl stream", (done: () => void) => {
    const model = modelsMap["polytopes/tetrahedron"]
    const asciiStlStream = fs.createReadStream(model.asciiPath)

    const asciiStreamTester = new StreamTester()
    asciiStreamTester.on("finish", () => done())
    return asciiStlStream.pipe(stlParser()).pipe(asciiStreamTester)
  })

  test("Returns an array of faces", (done: () => void) => {
    const asciiStl = fs.readFileSync(
      modelsMap["polytopes/tetrahedron"].asciiPath
    )

    return stlParser(asciiStl, { format: "json" }).on(
      "data",
      (polyhedron: Polyhedron) => {
        expectTriangleMesh(polyhedron)
        return done()
      }
    )
  })

  test("Handles stl-files with multi-word names", (done: () => void) => {
    const asciiStlStream = fs.createReadStream(
      modelsMap["misc/multiWordName"].asciiPath
    )
    const streamTester = new StreamTester({
      test(chunk: { name: string | null }) {
        if (chunk.name != null) {
          return expect(chunk.name).toBe("Model with a multi word name")
        }
      },
    })

    asciiStlStream.pipe(stlParser()).pipe(streamTester)

    return streamTester.on("finish", done)
  })

  test("Handles stl-files with a nameless solid", (done: () => void) => {
    const asciiStlStream = fs.createReadStream(
      modelsMap["misc/namelessSolid"].asciiPath
    )
    const streamTester = new StreamTester({
      test(chunk: { name: string | null }) {
        if (chunk.name) {
          return expect(chunk != null ? chunk.name : undefined).toBe("")
        }
      },
    })

    const parser = stlParser()
    parser.on("warning", (warning: string) =>
      expect(warning).toBe("Solid in line 1 does not have a name")
    )

    asciiStlStream.pipe(parser).pipe(streamTester)

    return streamTester.on("finish", done)
  })

  test("Handles stl-files with a missing endsolid keyword", (done: () => void) => {
    const asciiStlStream = fs.createReadStream(
      modelsMap["broken/missingEndsolid"].asciiPath
    )
    const streamTester = new StreamTester()

    const parser = stlParser()
    parser.on("error", (error: { message: string }) =>
      expect(error.message).toBe(
        "Provided ascii STL is not closed with endsolid keyword"
      )
    )

    asciiStlStream.pipe(parser).pipe(streamTester)

    return streamTester.on("finish", done)
  })

  test(//
  "Handles stl-files with missing normal coordinates", (done: () => void) => {
    const asciiStlStream = fs.createReadStream(
      modelsMap["broken/missingNormal"].asciiPath
    )
    let numberOfEvents = 0
    const streamTester = new StreamTester({
      test() {
        numberOfEvents += 1
      },
    })

    const parser = stlParser({ format: "jsonl" })
    parser.on("warning", (warning: string) => {
      const regexString =
        "^Unexpected 'outer' " +
        "instead of normal-(x|y|z) value in face 4, line 24"
      return expect(warning).toMatch(new RegExp(regexString))
    })

    asciiStlStream.pipe(parser).pipe(streamTester)

    return streamTester.on("finish", () => {
      expect(numberOfEvents).toBe(6)
      return done()
    })
  })

  test("Handles stl-files with NaN normal coordinates", (done: () => void) => {
    const asciiStlStream = fs.createReadStream(
      modelsMap["broken/notANumberNormal"].asciiPath
    )
    let numberOfEventsX = 0
    const streamTester = new StreamTester({
      test() {
        numberOfEventsX += 1
      },
    })

    const parser = stlParser({ format: "jsonl" })
    parser.on("warning", (warning: string) => {
      const regexString = `^Unexpected 'NaN' instead of \
normal-(x|y|z) value in face 2, line 9$`
      return expect(warning).toMatch(new RegExp(regexString))
    })

    asciiStlStream.pipe(parser).pipe(streamTester)

    return streamTester.on("finish", () => {
      expect(numberOfEventsX).toBe(6)
      return done()
    })
  })

  test("Emits a warning at mismatching solid and endsolid names", (done: () => void) => {
    const asciiStlStream = fs.createReadStream(
      modelsMap["broken/solidNameMismatch"].asciiPath
    )
    const streamTester = new StreamTester({
      test(chunk: { name: string | null }) {
        if (chunk.name != null) {
          return expect(chunk.name).toBe("tetrahedron")
        }
      },
    })

    const parser = stlParser()
    parser.on("warning", (warning: string) =>
      expect(warning).toBe(
        `Solid name ("tetrahedron") and endsolid name \
("anything but tetrahedron") do not match`
      )
    )

    asciiStlStream.pipe(parser).pipe(streamTester)

    return streamTester.on("finish", done)
  })

  test(`Emits a warning if an ascii-stl can probably be parsed \
as a binary-stl`, (done: () => void) => {
    const stlStream = fs.createReadStream(
      modelsMap["broken/wrongHeader"].binaryPath
    )
    const streamTester = new StreamTester()

    const parser = stlParser()
    parser.on("warning", (warning: string) =>
      expect(warning).toMatch(
        new RegExp(
          "^(Solid <no name> does not contain any faces)|" +
            "(Provided ascii STL should probably be parsed " +
            "as a binary STL)$"
        )
      )
    )
    parser.on("error", (error: { message: string }) =>
      expect(error.message).toBe("Provided ascii STL contains an invalid solid")
    )

    stlStream.pipe(parser).pipe(streamTester)

    return streamTester.on("finish", done)
  })

  test("Gets next word from internal buffer", () => {
    const asciiParser = new AsciiParser()
    asciiParser.internalBuffer = "this is a test string"

    return expect(asciiParser.getNextWord()).toBe("this")
  })

  test("Counts newlines surrounded by whitespace", () => {
    const asciiParser = new AsciiParser()
    asciiParser.internalBuffer = "this is \n a test \n string"

    while (asciiParser.getNextWord()) {
      /* empty body */
    }

    return expect(asciiParser.lineCounter).toBe(3)
  })

  test("Counts newlines surrounded by words", () => {
    const asciiParser = new AsciiParser()
    asciiParser.internalBuffer = "this is\na test\nstring"

    while (asciiParser.getNextWord()) {
      /* empty body */
    }

    return expect(asciiParser.lineCounter).toBe(3)
  })

  test("Fixes faces with 4 or more vertices and emits a warning", (done: () => void) => {
    const asciiStl = fs.readFileSync(modelsMap["broken/fourVertices"].asciiPath)

    return stlParser(asciiStl, { format: "json" })
      .on("warning", (warning: string) =>
        expect(warning).toBe("Face 1 has 4 instead of 3 vertices")
      )
      .on("data", (polyhedron: Polyhedron) => {
        expectTriangleMesh(polyhedron)
        return done()
      })
  })

  test("Fixes faces with 2 or less vertices and emits a warning", (done: () => void) => {
    const asciiStl = fs.readFileSync(modelsMap["broken/twoVertices"].asciiPath)

    return stlParser(asciiStl, { format: "json" })
      .on("warning", (warning: string) =>
        expect(warning).toBe("Face 1 has 2 instead of 3 vertices")
      )
      .on("data", (polyhedron: Polyhedron) => {
        expectTriangleMesh(polyhedron)
        return done()
      })
  })

  test("Emits progress events", (done: () => void) => {
    const filePath = modelsMap["polytopes/cube"].asciiPath
    const fileStats = fs.statSync(filePath)
    const asciiStlStream = fs.createReadStream(filePath)
    let numberOfProgressEvents = 0

    const parser = stlParser({ size: fileStats.size })
    parser
      .on("progress", (progress: number) => {
        expect(progress).toBeGreaterThanOrEqual(0)
        expect(progress).toBeLessThanOrEqual(1)
        return numberOfProgressEvents++
      })
      .on("finish", () => expect(numberOfProgressEvents).toBe(257))

    const streamTester = new StreamTester()
    streamTester.on("finish", done)

    return asciiStlStream.pipe(parser).pipe(streamTester)
  })

  test('Emits a header which contains a field "type" set to "ascii"', (done: () => void) => {
    const asciiStl = fs.readFileSync(
      modelsMap["polytopes/tetrahedron"].asciiPath
    )

    return stlParser(asciiStl, { format: "json" }).on(
      "data",
      (asciiData: { type: string }) => {
        expect(asciiData.type).toBe("ascii")
        return done()
      }
    )
  })

  return test.todo(
    "Can pipe large files into a file write-streamxxx",
    (done: () => void) => {
      const __dirname = path.dirname(new URL(import.meta.url).pathname)
      const outFilePath = path.resolve(__dirname, "temp.jsonl")

      // console.log(outFilePath)

      const fileWriteStream = fs.createWriteStream(outFilePath)
      fileWriteStream.on("end", () => {
        // console.log("end")
      })
      fileWriteStream.on("finish", () => {
        // console.log("done")
        fs.unlinkSync(outFilePath)
        return done()
      })

      return (
        fs
          // .createReadStream(modelsMap["objects/bunny"].asciiPath)
          .createReadStream(modelsMap["polytopes/tetrahedron"].asciiPath)
          .pipe(stlParser({ readableObjectMode: false, format: "jsonl" }))
          .pipe(fileWriteStream)
      )
    },
    50000
  ) // 20 seconds timeout
})
