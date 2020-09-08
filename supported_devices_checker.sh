#!/bin/bash


old_branch=$1; shift
new_branch=$1; shift

drvfile="drivers/net/ethernet/mellanox/mlx5/core/main.c"

get_supported_devs_from_branch()
{
	local branch=$1;shift

	echo "Getting list of supported devices from branch '$branch'..." >&2

	local tmp_unique=
	local tmp=
	tmp="$(git show ${branch}:${drvfile} \
		| grep -A100 'pci_device_id mlx5_core_pci_table' \
		| grep PCI_VDEVICE \
		| awk '{print $3}' | sed -e 's/).*//g')"
	for ii in $tmp
	do
		if (echo -e "${tmp_unique}" | grep -wq -- "${ii}"); then
			continue
		fi
		tmp_unique="${tmp_unique} ${ii}"
	done

	echo $tmp_unique
}


function check_dropped()
{
	local base=$1; shift
	local new=$1; shift

	echo
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "- Looking for devices dropped in the new branch (unlikley to happen)..."
	echo
	for ii in $base
	do
		if (echo -e "${new}" | grep -wq -- "${ii}"); then
			continue
		fi
		local desc="$(git show ${old_branch}:${drvfile} \
			| grep -A100 'pci_device_id mlx5_core_pci_table' \
			| grep PCI_VDEVICE \
			| grep -w -- "${ii}" \
			| sed -r -e 's@.*/\*(.*).*\*/@\1@')"
		echo "-E- '${ii}' '${desc}' is missing in new branch!" >&2
	done
}

function check_added()
{
	local base=$1; shift
	local new=$1; shift

	echo
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "- Looking for devices added in the new branch..."
	echo "- Consider adding these to mlx5_core_hw_unsupp_pci_table ..."
	echo
	for ii in $new
	do
		if (echo -e "${base}" | grep -wq -- "${ii}"); then
			continue
		fi
		local desc="$(git show ${new_branch}:${drvfile} \
			| grep -A100 'pci_device_id mlx5_core_pci_table' \
			| grep PCI_VDEVICE \
			| grep -w -- "${ii}" \
			| sed -r -e 's@.*/\*(.*).*\*/@\1@')"
		echo "-I- '${ii}' '${desc}' was added in new branch." >&2
	done
}

function check_status_in_RHEL()
{
	local branch=$1; shift
	local confs=$1; shift

	echo
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "- Current devices marked Tech-Preview in the branch '$branch' ..."
	echo
	git show ${branch}:${drvfile} \
		| grep -A2000 'pci_device_id mlx5_core_hw_unsupp_pci_table' \
		| grep -B2000 'pci_device_id mlx5_core_pci_table' \
		| grep PCI_VDEVICE
}

if [[ "X"${old_branch}" == "X" -o "X"${new_branch}" == "X" ]]; then
	echo "-E- missing old_branch or new_branch" >&2
	exit 1
fi

# find in old branch
old_devs=$(get_supported_devs_from_branch $old_branch)

# find in new branch
new_devs=$(get_supported_devs_from_branch $new_branch)

# check for dropped
check_dropped "$old_devs" "$new_devs"

# check for added
check_added "$old_devs" "$new_devs"

# check devs marked as Tech-Preview
check_status_in_RHEL "$new_branch" "$new_devs"
