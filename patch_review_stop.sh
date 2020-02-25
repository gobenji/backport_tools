#!/bin/bash
set -ex

curr_branch=$(git branch | grep "^* " | awk '{print $2}')

if [ "X${curr_branch}" != "Xreviewbranch" ]; then
	echo "-E- You are not on review branch!" >&2
	exit 1
fi

orig_branch=$(cat .orig_branch)
git checkout ${orig_branch}

/bin/rm -rf toreview 
/bin/rm -rf toreview_work
/bin/rm -rf .data
/bin/rm -f .orig_branch
git branch -D reviewbranch

