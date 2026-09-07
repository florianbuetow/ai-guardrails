#!/bin/sh
set -eu
if [ "$#" -eq 1 ];then
printf '%s\n' "$1"
fi
