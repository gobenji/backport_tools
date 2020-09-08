#!/bin/bash
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

shopt -s expand_aliases
source ${SCRIPTPATH}/bashrc_addons.sh
set -e

echo "-------------------------------------------------------------------"
echo "Working with:"
echo ""
env QUILT_PAGER="" quilt header
echo ""
echo "-------------------------------------------------------------------"
echo ""

commit=$(quilt header | grep "^commit" | awk '{print $2}')
if [ "X${commit}" == "X" ]; then
	echo "Failed to get commit ID!!!" >&2
	exit 1
fi

echo "Looking up commit $commit in git log ..."
echo ""
git --no-pager log --grep $commit
