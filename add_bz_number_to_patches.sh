#!/bin/bash -e

BZNUM=$1; shift
FILES=$@

if [ "X${BZNUM}" == "X" ]; then
	echo "BZNUM not given" >&2
	exit 1
fi

BZNUM="Bugzilla: http://bugzilla.redhat.com/${BZNUM}"

append_bznum_to_file()
{
	local ff=$1; shift

	if [ ! -e "${ff}" ]; then
		echo "patch does not exist at: ${ff}" >&2
		exit 1
	fi

	# don't duplicate it
	if (grep -qw "${BZNUM}" ${ff}); then
		echo "Already exists in ${ff} , skipping"
		return
	fi
	# check if there is no "Bugzilla:" tag at all, as then we don't know where to add the new tag
	if !(grep -q "^Bugzilla: " ${ff}); then
		echo "Missing 'Bugzilla:' tag in ${ff} , skipping"
		return
	fi

	echo "Adding to ${ff}"
	awk "{print} /Bugzilla: / && !n {print \"${BZNUM}\"; n++}" ${ff} > /var/tmp/tmpff && mv /var/tmp/tmpff ${ff}
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
			append_bznum_to_file ${jj}
		done
		continue
	fi

	append_bznum_to_file ${ii}
done
