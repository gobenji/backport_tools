#!/bin/bash
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
. ${SCRIPTPATH}/config.sh

shopt -s expand_aliases
source ${SCRIPTPATH}/bashrc_addons.sh
set -e

echo "-------------------------------------------------------------------"
echo "Working with:"
echo ""
quilt header
echo ""
echo "-------------------------------------------------------------------"
echo ""

commit=$(quilt header | grep "^commit" | awk '{print $2}')
if [ "X${commit}" == "X" ]; then
	echo "Failed to get commit ID!!!" >&2
	exit 1
fi
echo "commit $commit"

cfile=$(quilt applied | tail -1)

cd ${TREE}
/bin/rm -rf /tmp/quilt_preview
mkdir -p /tmp/quilt_preview
git format-patch -1 ${commit} -o /tmp/quilt_preview
cd -

vimdiff patches/${cfile} /tmp/quilt_preview/*patch
