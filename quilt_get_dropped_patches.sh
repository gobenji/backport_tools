#!/bin/bash -e
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
. ${SCRIPTPATH}/config.sh

pdir=${1:-patches}

pdir=$(readlink -f ${pdir})
if [ ! -e "${pdir}" ]; then
	echo "-E- patches folder does not exit !" >&2
	exit 1
fi

echo "Working with: ${pdir}"
echo

cd ${TREE}
for pp in $(grep "^#[0-9]" ${pdir}/series)
do
	echo "${pp}"
	cid=$(echo ${pp} | sed -r -e 's/#.*-(.*).(diff|patch)/\1/g')
	git log -1 --oneline --decorate ${cid} 2>/dev/null || true
	echo "----------------------------------------------"
done
