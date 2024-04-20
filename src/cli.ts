import chalk from "chalk"

import StlParser from "./StlParser.ts"

type CliOptions = {
  ascii?: boolean
  binary?: boolean
  type?: "ascii" | "binary"
  readableObjectMode?: boolean
}

export default function (options: CliOptions = {}) {
  if (process.stdin.isTTY) {
    return console.error(
      chalk.red(
        "STL-parser must be used by piping into it.\n" +
          "Example: `cat file.stl | stl-parser"
      )
    )
  }

  if (options.ascii) {
    delete options.ascii
    options.type = "ascii"
  }
  if (options.binary) {
    delete options.binary
    options.type = "binary"
  }

  options.readableObjectMode = false

  const stlParser = new StlParser(options)
  process.stdin //
    .pipe(stlParser)
    .pipe(process.stdout)

  stlParser.on("error", (error) => console.error(chalk.red(error.stack)))

  stlParser.on("warning", (warning) =>
    console.warn(chalk.yellow("Warning:", warning))
  )

  return stlParser.on("debug", (debugInfo) =>
    console.warn(chalk.cyan("Debug:", debugInfo))
  )
}
