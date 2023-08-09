#!/usr/bin/env bash

rm -rf ./doc
jsdoc ./lib/*.js README.md -d ./doc/