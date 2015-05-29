#! /usr/bin/env node

var yargs = require('yargs')

require('../build/cli')(yargs.argv)
