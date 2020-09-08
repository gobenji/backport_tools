#!/bin/bash
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
. ${SCRIPTPATH}/config.sh

BRANCH=${BRANCH:-'HEAD'}

function get_one()
{
	subj=$(echo "${1}" | sed -r -e 's/^\s*//g' -e 's/$\s*//g' -e 's/\xc2\xa0//g')
	if [ "X${subj}" == "X" ]; then
		continue
	fi
	echo "# ${subj}"
	git log ${BRANCH} --oneline --no-merges --grep "${subj}"
}

cd ${TREE}
while [ "X${1}" != "X" ]
do
	if [ -f "$1" ]; then
		while read -r cline
		do
			get_one "${cline}"
		done < <(cat ${1})

		shift
		continue
	fi

	get_one "${1}"
	shift
done

