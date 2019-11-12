#!/bin/bash -e

BZNUM=$1; shift
INPUTF=${1:-"list.txt"}

if [ "X${BZNUM}" == "X" ]; then
	echo "BZNUM not given" >&2
	exit 1
fi

if [ ! -e "${INPUTF}" ]; then
	echo "input list file missing/does not exist at: '${INPUTF}'" >&2
	exit 1
fi

echo "Using: ${INPUTF}"
echo

hashes=""

while read -r cline
do
	case "${cline}" in
		\#*)
			continue
			;;
		"")
			continue
			;;
	esac

	hash=$(echo "${cline}" | sed -e 's/ .*//g')
	if [ "X${hash}" == "X" ]; then
		echo -e "failed to get hash from line:\n${cline}" >&2
		exit 1
	fi

	if [ "X${hashes}" == "X" ]; then
		hashes="${hash}"
	else
		hashes="${hashes}|${hash}"
	fi
done < <(cat ${INPUTF})


if [ "X${hashes}" == "X" ]; then
	echo "no hashes found" >&2
	exit 1
fi

add_bz_number_to_patches.sh ${BZNUM} $(find * | grep -E "${hashes}")
