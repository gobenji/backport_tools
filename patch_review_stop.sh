#!/bin/bash -ex

orig_branch=$(cat .orig_branch)
git checkout ${orig_branch}

/bin/rm -rf toreview 
/bin/rm -rf toreview_work
/bin/rm -rf .data
/bin/rm -f .orig_branch
git branch -D reviewbranch

