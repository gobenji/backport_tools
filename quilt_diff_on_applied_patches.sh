#!/bin/bash -e
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
. ${SCRIPTPATH}/config.sh

pdir=${1:-patches}

SHOW_FNAME_ONLY=${SHOW_FNAME_ONLY:-"0"}

pdir=$(readlink -f ${pdir})
if [ ! -e "${pdir}" ]; then
	echo "-E- patches folder does not exit !" >&2
	exit 1
fi

echo "Working with: ${pdir}"
echo

cd ${TREE}
for pp in $(grep "^[0-9]" ${pdir}/series)
do
	if [ "X${SHOW_FNAME_ONLY}" != "X0" ]; then
		echo "${pp}"
		continue
	fi
	cid=$(echo ${pp} | sed -r -e 's/.*-(.*).(diff|patch)/\1/g')
	if !(git log -1 --oneline --no-decorate ${cid} 2>/dev/null); then
		cid=$(grep "^From " ${pdir}/${pp} | cut -d" " -f2)
		if [ "X${cid}" == "X" ]; then
			cid=$(grep "^commit " ${pdir}/${pp} | cut -d" " -f2)
		fi
		if [ "X${cid}" == "X" ]; then
			echo "Failed to get commit ID of $pp !" >&2
			exit 1
		fi
	fi
	read -p "Review diff (y/n)?" choice
	case "$choice" in
		y*|Y*)
			git log -1 --oneline --no-decorate ${cid} 2>/dev/null
			/bin/rm -rf /tmp/diffdirr
			git format-patch -1 -o /tmp/diffdirr ${cid}
			vimdiff ${pdir}/${pp} /tmp/diffdirr/*
			/bin/rm -rf /tmp/diffdirr
			;;
	esac
#	echo "----------------------------------------------"
done
