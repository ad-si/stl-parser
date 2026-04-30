import path from "path"
import os from "os"
import childProcess, { ExecException } from "child_process"

import { test, expect, describe } from "bun:test"
import { ModelsMap } from "../src/types.ts"
import { models } from "./helper.ts"

const __dirname = path.dirname(new URL(import.meta.url).pathname)

const modelsMap = models.reduce((previous, current, index) => {
  previous[current.name] = models[index]
  return previous
}, {} as ModelsMap)

if (!/^win/.test(String(os.platform))) {
  describe("CLI", () => {
    test.todo(
      "Parses an ascii-stl file-stream",
      function (done: (err?: ExecException | string) => void) {
        const filePath = modelsMap["polytopes/cube"].asciiPath

        childProcess.exec(
          `${path.join(__dirname, "../cli/index.ts")} < ${filePath}`,
          function (error, stdout, stderr) {
            if (error) {
              return done(error)
            }
            if (stderr) {
              return done(stderr)
            }
            expect(stdout.length).toBe(1476)
            done()
          }
        )
      }
    )

    test.todo(
      "Pipes an large ascii-stl file into a file-stream",
      (done: (err?: ExecException) => void) => {
        const filePath = modelsMap["objects/bunny"].asciiPath

        childProcess.exec(
          `${path.join(__dirname, "../cli/index.ts")} < ${filePath}`,
          function (_error, _stdout, stderr) {
            if (stderr) {
              return done(new Error(stderr))
            }
            done()
          }
        )
      }
    )

    test.todo(
      "Parses an binary-stl file-stream",
      (done: (err?: ExecException | string) => void) => {
        const filePath = modelsMap["polytopes/cube"].binaryPath

        childProcess.exec(
          `${path.join(__dirname, "../cli/index.ts")} < ${filePath}`,
          function (error, stdout, stderr) {
            if (error) {
              return done(error)
            }
            if (stderr) {
              return done(stderr)
            }
            expect(stdout.length).toBe(1660)
            done()
          }
        )
      }
    )
  })
}
