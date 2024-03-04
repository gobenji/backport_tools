#!/bin/bash

#bznum=$(git describe --contains --all HEAD | awk -F "v" ' { print $1 }')
bznum=$(git branch --show-current)
ver=".jr${bznum}"
if [ "X${1}" != "X" ]; then
	ver="${ver}.${1}"
else
	ver="${ver}.v1"
fi
echo "${ver}" > localversion
cat localversion
