#!/bin/bash
set -ex

curr_branch=$(git branch | grep "^* " | awk '{print $2}')
base_branch=${1:-"master"}
if [ "X${curr_branch}" != "X" -a "X${base_branch}" == "Xmaster" ]; then
	if (git branch | grep -qw "master.${curr_branch}"); then
		base_branch="master.${curr_branch}"
	fi
fi

if [ "X${curr_branch}" == "Xreviewbranch" ]; then
	echo "-I- You are already on review branch, will only run patchreview tool"
else
	echo "-I- Preparing stuff before running patchreview tool..."

	echo "${curr_branch}" > .orig_branch


	/bin/rm -rf toreview
	git format-patch ${base_branch} -o toreview
	git co ${base_branch} -B reviewbranch

	/bin/rm -rf toreview_work
	mkdir toreview_work

	/bin/rm -rf .data
	mkdir .data
	cat > .data/patchreview.prj << EOF
0
1
0
0
1
1
vimdiff
toreview
toreview_work
false
true
10
EOF
fi

patchreview
