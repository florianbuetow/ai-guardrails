#!/bin/sh
set -eu
git ls-files --cached -z > build/tracked-files.txt
git ls-files --others --exclude-standard -z > build/files.txt
git ls-files --others --ignored --exclude-standard -z > build/ignored-files.txt
build/assert tracked build/tracked-files.txt
build/assert artifacts build/files.txt
build/assert artifacts build/ignored-files.txt
