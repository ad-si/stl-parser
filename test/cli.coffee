#! /usr/bin/env coffee

yargs = require 'yargs'
cli = require '../src/cli'

cli yargs.argv
