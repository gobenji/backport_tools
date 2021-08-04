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
3
0
0
0
1
vimdiff
toreview
toreview_work
2



1
false
false
17
EOF

	cat > .data/patchreview.conf << EOF
menumode         = 0
patchvalfuzz     = 3
patchseekmode    = 0
applyfailmode    = 0
applymode        = 0
cmpmode          = 1
editor           = vimdiff
indir            = toreview
outdir           = toreview_work
background       = 2
remote_repo      = origin
remote_branch    = 
mergelist_filter =
opmode           = 1
b_rename_infiles = false
b_fmt_upstream   = false
b_verbose        = true
b_mrcomments     = true
EOF

fi

patchreview
