#! /usr/bin/env bun run

import yargs from "yargs"
import { hideBin } from "yargs/helpers"
import cli from "../src/cli.ts"

const argv = yargs(hideBin(process.argv)).parseSync()
cli({
  ascii: Boolean(argv.ascii),
  binary: Boolean(argv.binary),
})
