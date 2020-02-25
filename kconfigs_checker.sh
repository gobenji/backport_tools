#!/bin/bash


old_branch=$1; shift
new_branch=$1; shift

subdirs="\
	drivers/net/ethernet/mellanox/mlx5/core \
	drivers/net/ethernet/mellanox/mlx4/ \
	drivers/infiniband/hw/mlx5 \
	drivers/infiniband/hw/mlx4 \
	"

function get_kconfig_files_from_branch()
{
	local branch=$1; shift

	git ls-tree -r --name-only $branch $subdirs | grep -E "Makefile|Kconfig"
}

function get_kconfig_from_file()
{
	local branch=$1; shift
	local file=$1; shift

	local list1=$(git show ${branch}:${file} | grep -- -\$\(.*\) | sed -r -e 's/.*-\$\((.*)\)\s.*/\1/')

	for ii in $(git show ${branch}:${file} | grep -- "^config" | sed -r -e 's/config\s*//g')
	do
		list1="${list1} CONFIG_${ii}"
	done

	echo "$list1"
}

function make_unique()
{
	local input=$1; shift
	local output=

	for ii in $input
	do
		if (echo -e "${output}" | grep -wq -- "${ii}"); then
			continue
		fi
		output="${output} ${ii}"
	done
	echo $output
}

function get_unique_kconfigs_from_branch()
{
	local branch=$1;shift

	echo "Getting list of kconfigs from branch '$branch' ..." >&2

	local flist=$(get_kconfig_files_from_branch $branch)
	local tmp=
	for ff in $flist
	do
		tmp="${tmp} $(get_kconfig_from_file $branch $ff)"
	done

	make_unique "$tmp"
}

function check_dropped()
{
	local base=$1; shift
	local new=$1; shift

	echo
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "- Looking for kconfigs dropped in the new branch..."
	echo
	for ii in $base
	do
		if (echo -e "${new}" | grep -wq -- "${ii}"); then
			continue
		fi
		echo "-E- '${ii}' is missing in new branch Makefile/Kconfig!" >&2
	done
}

function check_added()
{
	local base=$1; shift
	local new=$1; shift

	echo
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "- Looking for kconfigs added in the new branch..."
	echo
	for ii in $new
	do
		if (echo -e "${base}" | grep -wq -- "${ii}"); then
			continue
		fi
		echo "-I- '${ii}' was added in new branch Makefile/Kconfig." >&2
	done
}

function check_status_in_RHEL()
{
	local branch=$1; shift
	local confs=$1; shift

	echo
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "- Looking for kconfigs status in the branch '$branch' ..."
	echo
	for ii in $confs
	do
		echo "---------------------------------------------------------------"
		if ! git grep -w ${ii} ${branch} -- redhat/configs/ ; then
			echo "-E- '${ii}' is not defined under ${branch}:redhat/configs/" >&2
		fi
	done
}

if [[ "X"${old_branch}" == "X" -o "X"${new_branch}" == "X" ]]; then
	echo "-E- missing old_branch or new_branch" >&2
	exit 1
fi

# find in old branch
old_conf=$(get_unique_kconfigs_from_branch $old_branch)

# find in new branch
new_conf=$(get_unique_kconfigs_from_branch $new_branch)

# check for dropped
check_dropped "$old_conf" "$new_conf"

# check for added
check_added "$old_conf" "$new_conf"

# check values of current kconfigs in redhat/configs/ in new branch
check_status_in_RHEL "$new_branch" "$new_conf"
