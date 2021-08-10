#!/bin/bash
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
. ${SCRIPTPATH}/config.sh

cid=$1; shift

cd $TREE

if [ "X${cid}" == "X" ]; then
	echo "-E- Commit ID not given!" >&2
	exit 1
fi

status=$(git describe --contains $cid 2>/dev/null | sed -e 's/~.*//g')
if [ "X${status}" == "X" ]; then
	status=$(git branch -r --contains $cid | grep -v HEAD | head -1)
else
	case "$status" in
		v*)
			;;
		*)
			status=$(git tag --contains $cid | grep "^v[3-9]" | head -1)
			;;
	esac
fi

if [ "X${status}" == "X" ]; then
	status=$(git branch -r --contains $cid | grep -v HEAD | head -1)
fi

if [ "X${status}" == "X" ]; then
	echo "-E- Cannot find commit: $cid !" >&2
	exit 1
fi

status=$(echo $status | sed -e 's/\s//g')

# display the repo URL instead of just its name
case "$status" in
	v*)
		;;
	*)
		repo1=$(echo ${status} | sed -e 's/\/.*//g')
		branch1=$(echo ${status} | sed -e 's/.*\///g')
		repo1=$(git remote show ${repo1} | grep "Fetch URL:" | sed -e 's/.*URL: //g')
		status="${repo1} , branch: ${branch1}"
		;;
esac

echo "Upstream-status: ${status}"
