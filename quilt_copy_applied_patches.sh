#!/bin/bash -e
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
. ${SCRIPTPATH}/config.sh

tdir=${1}; shift
if [ ! -e "${tdir}" ]; then
	echo "tdit does not exist or not given!" >&2
	exit 1
fi

pdir='patches'

pdir=$(readlink -f ${pdir})
if [ ! -e "${pdir}" ]; then
	echo "-E- patches folder does not exit !" >&2
	exit 1
fi

echo "Working with: ${pdir}"
echo "Copying to:   ${tdir}"
echo

cd ${TREE}
count=0
for pp in $(grep "^[0-9]" ${pdir}/series)
do
	set +e
	let count++
	set -e

	cid=$(echo ${pp} | sed -r -e 's/.*-(.*).(diff|patch)/\1/g')
	full_cid=$(git log -1 --format="%H" ${cid} 2>/dev/null || true)
	if [ "X${full_cid}" == "X" ]; then
		cid=$(grep "^From " ${pdir}/${pp} | cut -d" " -f2)
		if [ "X${cid}" == "X" ]; then
			cid=$(grep "^commit " ${pdir}/${pp} | cut -d" " -f2)
		fi
		if [ "X${cid}" == "X" ]; then
			echo "Failed to get commit ID of $pp !" >&2
			exit 1
		fi
		full_cid=$(git log -1 --format="%H" ${cid} 2>/dev/null)
		if [ "X${full_cid}" == "X" ]; then
			echo "Can't find commit: ${cid}" >&2
			exit 1
		fi
	fi

	new_num=$(printf "%04d\n" $count)
	nfname="${new_num}-${full_cid}.patch"
	echo "${nfname}"
	cp -i ${pdir}/${pp} ${tdir}/${nfname}
done
