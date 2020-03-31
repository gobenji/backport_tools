#!/bin/bash
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

shopt -s expand_aliases
source ${SCRIPTPATH}/bashrc_addons.sh
set -e

PATCH_DIRS_LIST="${PATCH_DIRS_LIST:-PATCH_DIRS_LIST.txt}"

if [ ! -e "${PATCH_DIRS_LIST}" ]; then
	echo "Conf file missing/does not exist at: '${PATCH_DIRS_LIST}'" >&2
	exit 1
fi

echo "Using: ${PATCH_DIRS_LIST}"
echo

INC_BUILD_TEST=0
RESOLVED=0

if [ "X${1}" != "X" ]; then
	case "${1}" in
		inc)
			read -p "Do you really want to test incremental build?" choice
			case "$choice" in
				y*|Y*)
					INC_BUILD_TEST=1
					;;
				*)
					echo "Aborted."
					exit 0
					;;
			esac
			echo
			;;
		resolved)
			RESOLVED=1
			;;
		*)
			echo "-E- Unsupported option: '${1}' !" >&2
			exit 1
			;;
	esac
fi

refresh_and_apply_series()
{
	local pdir=$1; shift

	set_patches_link ${pdir}

	if [ $INC_BUILD_TEST -eq 1 ]; then
		incremental_build_mlx_mods.sh
		quilt_pop
	fi

	# refresh to make sure git am will work
	quilt_refresh
	quilt_pop

	git_apply_quilt_series
}


if [ $INC_BUILD_TEST -eq 0 -a $RESOLVED -eq 0 ]; then
	prepare_dev_branch.sh
fi

resume_started=0
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

	# resume from the last folder where we stopped before, as we might
	# already ran this and had to fix some build issue.
	cline_full=$(readlink -f ${cline})
	current_patches_full=$(readlink -f patches)
	if [ $INC_BUILD_TEST -eq 1 -o $RESOLVED -eq 1 ] && [ "X${current_patches_full}" != "X" ] && [ $resume_started -eq 0 ]; then
		if [ "X${cline_full}" != "X${current_patches_full}" ]; then
			continue
		fi
		echo "Resuming ..."
		resume_started=1
	fi

	echo
	echo "------------------------------------------------------"

	if echo "${cline}" | grep -q "^SWITCH_BRANCH" ; then
		git_branch=$(echo "${cline}" | sed -e 's/.*#//g')
		if [ "X${git_branch}" == "X" ]; then
			echo "Failed to get git_branch!" >&2
			exit 1
		fi

		echo
		echo "Switching to branch: ${git_branch}"
		git checkout -B ${git_branch}

		echo
		echo "Setting current branch as master branch for: ${git_branch}"
		set_master_branch.sh

		continue
	fi

	echo "Working with: '${cline}'"
	if ! [ -d "${cline}" ]; then
		echo "-E- Patch dir does not exist '${cline}' !" >&2
		exit 1
	fi

	refresh_and_apply_series ${cline}

done < <(cat ${PATCH_DIRS_LIST})
