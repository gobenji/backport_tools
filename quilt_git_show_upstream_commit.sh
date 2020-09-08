#!/bin/bash
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
. ${SCRIPTPATH}/config.sh

shopt -s expand_aliases
source ${SCRIPTPATH}/bashrc_addons.sh
set -e

commit=$(quilt header | grep "^commit" | awk '{print $2}' | sed -e 's/\r//g')
if [ "X${commit}" == "X" ]; then
	echo "Failed to get commit ID!!!" >&2
	exit 1
fi

cd ${TREE}
git show ${commit}
