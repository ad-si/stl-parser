import fs from "fs"

import { test, describe } from "bun:test"
import stlParser from "../src/index.ts"
import { ModelsMap } from "../src/types.ts"
import { equalFaces, models } from "./helper.ts"

const modelsMap = models.reduce((previous, current, index) => {
  previous[current.name] = models[index]
  return previous
}, {} as ModelsMap)

describe("STL Parser", () =>
  test.todo(
    "Ascii & binary stl have equal faces (maximum delta: 0.00001)",
    (done: () => void) => {
      const asciiStl = fs.readFileSync(modelsMap["objects/gearwheel"].asciiPath)
      const binaryStl = fs.readFileSync(
        modelsMap["objects/gearwheel"].binaryPath
      )

      return stlParser(asciiStl, { format: "json" }).on(
        "data",
        (asciiData: { faces: any[] }) =>
          stlParser(binaryStl, { format: "json" }).on(
            "data",
            (binaryData: { faces: any[] }) => {
              equalFaces(asciiData.faces, binaryData.faces)
              return done()
            }
          )
      )
    }
  ))
