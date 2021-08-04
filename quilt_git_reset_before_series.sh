#!/bin/bash
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
. ${SCRIPTPATH}/config.sh

pdir=${1:-patches}
pdir=$(readlink -f ${pdir})
if [ ! -e "${pdir}" ]; then
	echo "-E- patches folder does not exit !" >&2
	exit 1
fi

first_patch=$(quilt series | head -1)
if [ "X${first_patch}" == "X" ]; then
	echo "-E- Can't get first patch from quilt series!" >&2
	exit 1
fi
if [ ! -e "${pdir}/${first_patch}" ]; then
	echo "-E- Can't find file '${pdir}/${first_patch}'!" >&2
	exit 1
fi

subj=$(grep "Subject:" ${pdir}/${first_patch} 2>/dev/null | sed -e 's/Subject:\s*//g')
if [ "X${subj}" == "X" ]; then
	echo "-E- Can't find commit Subject in '${pdir}/${first_patch}'" >&2
	exit 1
fi

echo "First patch in the series: ${first_patch} ( ${subj} )"
backport_commit=$(git log --oneline --grep "${subj}" | grep "${subj}")
if [ "X${backport_commit}" == "X" ]; then
	echo "-E- Can't find commit in git log: '${subj}'" >&2
	exit 1
fi
if [ $(echo "${backport_commit}" | wc -l) -ne 1 ]; then
	echo "-E- Found multiple matches! review them and reset manually to the needed one." >&2
	echo "${backport_commit}" >&2
	exit 1
fi

echo "Backport commit: ${backport_commit}"
cid=$(echo "${backport_commit}" | cut -d' ' -f1)
git reset --hard ${cid}^1
