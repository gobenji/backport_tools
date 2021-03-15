#!/bin/bash
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

shopt -s expand_aliases
source ${SCRIPTPATH}/bashrc_addons.sh
set -e

CNB_INFO=${CNB_INFO:-"CNB.txt"}
bznum=$(git branch | grep "^* " | awk '{print $2}')

if [ "X${bznum}" == "Xmaster" ]; then
	echo "You are on master branch! first move to a branch with name of BZ number" >&2
	exit 1
fi

if [ ! -e "${CNB_INFO}" ]; then
	echo "Conf file missing/does not exist at: '${CNB_INFO}'" >&2
	exit 1
fi

echo "Using: ${CNB_INFO}"
echo
read -p "This will OVERRIDE your current branch ${bznum} and master.${bznum} branch, continue (y/n)?" choice
case "$choice" in
	y*|Y*)
		;;
	*)
		echo "Aborted."
		exit 1
		;;
esac
echo

git remote update

# make sure we are in a clean state
quilt_pop &>/dev/null || true
git merge --abort &>/dev/null || true
git am --abort &>/dev/null || true
_clean_rej

if (git branch -r | grep -q rhel-8.0); then
	base=$(grep "^BASE" ${CNB_INFO} | sed -e 's/.*#//g')
	if [ "X${base}" == "X" ]; then
		echo "Must add: 'BASE#<branch>' for RHEL-8 tree" >&2
		exit 1
	fi
	git reset --hard ${base}
else
	base=$(grep "^BASE" ${CNB_INFO} | sed -e 's/.*#//g')
	if [ "X${base}" == "X" ]; then
		git reset --hard origin/master
	else
		git reset --hard ${base}
	fi
fi

while read -r cline
do
	case "${cline}" in
		\#*)
			continue
			;;
		"")
			continue
			;;
		BASE*)
			continue
			;;
	esac

	echo "At: '${cline}'"

	git_url=$(echo "${cline}" | sed -e 's/#.*//g')
	git_branch=$(echo "${cline}" | sed -e 's/.*#//g')
	if [ "X${git_url}" == "X" ]; then
		echo "Failed to get git_url!" >&2
		exit 1
	fi
	if [ "X${git_branch}" == "X" ]; then
		echo "Failed to get git_branch!" >&2
		exit 1
	fi

	if [ "X${git_url}" == "XAPPLY_PATCH" ]; then
		echo
		echo "------------------------------------------------------"
		echo "Applying patch: ${git_branch}"
		git am --reject ${git_branch}
		echo
		continue
	fi

	if [ "X${git_url}" == "XAPPLY_PATCH_DIR" ]; then
		echo
		echo "------------------------------------------------------"
		echo "Applying patches from folder: ${git_branch}"
		git am --reject ${git_branch}/*patch
		echo
		continue
	fi

	echo
	echo "------------------------------------------------------"
	echo "Merging with ${git_url} , branch: ${git_branch}"
	set +e
	merge_with=FETCH_HEAD
	git fetch ${git_url} ${git_branch}
	if [ $? -ne 0 ]; then
		# maybe it's a tag
		echo "Checking if it's a tag..."
		if (git ls-remote --tags ${git_url} | grep ${git_branch}); then
			git fetch ${git_url}
			merge_with=${git_branch}
		else
			echo "Failed to fetch ${git_url} ${git_branch}"
			exit 1
		fi
	fi
	git merge --signoff --log=1000 --no-edit ${merge_with}
	if [ $? -ne 0 ]; then
		# W/A rerere does not handle deleted file
		for ff in $(git status | grep "deleted by" | cut -d":" -f2)
		do
			git rm ${ff}
		done

		xx=$(git diff 2>&1)
		if [ "X${xx}" == "X" ]; then
			# resolved by rerere cache
			set -e
			git commit -s --no-edit
		else
			# new merge conflicts, fail it
			exit 1
		fi
	fi
	set -e

done < <(cat ${CNB_INFO})

# now set master to this clean base, so that when we generate patches it will contain only our work
git branch -f master.${bznum} HEAD

