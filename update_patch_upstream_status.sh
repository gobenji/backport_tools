#!/bin/bash -e
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
. ${SCRIPTPATH}/config.sh

FILES=$@

update_status_for_patch()
{
	local ff=$1; shift

	echo "At: ${ff}"

	if [ ! -e "${ff}" ]; then
		echo "patch does not exist at: ${ff}" >&2
		exit 1
	fi

	if (grep -q "^Upstream: v" ${ff}); then
		echo "already updated, skipping..."
		return
	fi
	if !(grep -q "^Upstream: " ${ff}); then
		echo "Missing 'Upstream:' tag, skipping..."
		return
	fi

	cd ${TREE}
	cid=$(echo ${ff} | sed -r -e 's@.*/@@g' | sed -r -e 's/.*-(.*).(diff|patch)/\1/g')
	if !(git log -1 --oneline --decorate ${cid} &>/dev/null); then
		cid=$(grep "^From " ${ff} | cut -d" " -f2)
		if [ "X${cid}" == "X" ]; then
			cid=$(grep "^commit " ${ff} | cut -d" " -f2)
		fi
		if [ "X${cid}" == "X" ]; then
			cid=$(echo ${ff} | sed -r -e 's@.*/@@g' | sed -r -e 's/(.*).(diff|patch)/\1/g')
		fi
		if [ "X${cid}" == "X" ]; then
			echo "Failed to get commit ID of ${ff} !" >&2
			exit 1
		fi
		if !(git log -1 --oneline --decorate ${cid} &>/dev/null); then
			echo "Commit ID of ${ff} is BAD!" >&2
			exit 1
		fi
	fi
	cd - &>/dev/null

	status=$(get_patch_upstream_status.sh ${cid})
	if (echo "${status}" | grep -q "^Upstream: v"); then
		echo "Updating ${ff} to ${status}"
		sed -ir -e "s/^Upstream: .*/${status}/" ${ff}
		# remove bkp file
		/bin/rm -fv ${ff}r
	else
		echo "No tag yet for this patch."
	fi
}

for ii in ${FILES}
do
	if [ ! -e "${ii}" ]; then
		echo "skipping none existing patch: ${ii}"
		continue
	fi

	if [ -d "${ii}" ]; then
		for jj in $(/bin/ls -1 ${ii}/*{diff,patch} 2>/dev/null)
		do
			update_status_for_patch ${jj}
		done
		continue
	fi

	update_status_for_patch ${ii}
done
