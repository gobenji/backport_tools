#!/bin/bash
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
. ${SCRIPTPATH}/config.sh

if [ ! -e "${1}" ]; then
	echo "File not given or not found: '${1}'" >&2
	exit 1
fi

vimdiff ${1} ${TREE}/${1}
