#!/bin/bash -e
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
. ${SCRIPTPATH}/config.sh

rhel_tree=$1; shift
rhel_start_ref=$1; shift
start_ref=$1; shift
tdir=$1; shift

drv_dirs=${drv_dirs:-"mlx4 mlx5"}

BRANCHES="origin/master net-next/master net/master rdma/for-next rdma/for-rc"


if [ ! -e "${rhel_tree}" ]; then
	"-E- must provide rhel_tree to scan for already backported and new relevant fixes!"
	exit 1

fi

if [ "X${start_ref}" == "X" ]; then
	"-E- must provide start_ref to get patches that were added after that ref!"
	exit 1

fi

if [ "X${tdir}" == "X" ]; then
	"-E- must provide target dir to save list files at!"
	exit 1

fi

cd ${TREE}
git remote update

mkdir -p ${tdir}
cd ${rhel_tree}


branch_to_fname()
{
	echo "$1" | sed -e 's@/@_@g'
}

for bb in ${BRANCHES}
do
	echo
	echo "Getting fixes from ${bb} ..."
	tfname=$(branch_to_fname ${bb})

	python3 ${SCRIPTPATH}/git-change-log \
		-o ${rhel_start_ref}.. \
		-u ${start_ref}..${bb} \
		--old_kernel_path . \
		--upstream_kernel_path ${TREE} \
		--dirs ${drv_dirs} \
		--get_fixes \
		| tee ${tdir}/${tfname}.txt
done


echo
echo "-------------------------------------------------------------------"
echo
echo "Now creating on file that includes everything..."
full_list_file="${tdir}/full_list.txt"
echo "" > ${full_list_file}

for bb in ${BRANCHES}
do
	tfname=$(branch_to_fname ${bb})
	tf="${tdir}/${tfname}.txt"
	echo
	echo "Scanning ${tf} ..."

	note=
	prev_had_note=0
	while read -r cline
	do
		if (echo "${cline}" | grep -qw "Note:"); then
			note=${cline}
			continue
		fi
		hash=$(echo "${cline}" | sed -e 's/ .*//g')
		if !(grep -wq "${hash}" ${full_list_file}); then
			echo "Found new fix: ${cline}"
			if [ "X${note}" != "X" ]; then
				if [ $prev_had_note -eq 0 ]; then
					echo "" >> ${full_list_file}
				fi
				echo "${note}" >> ${full_list_file}
				prev_had_note=1
			else
				prev_had_note=0
			fi
			echo "${cline}" >> ${full_list_file}
			if [ "X${note}" != "X" ]; then
				echo "" >> ${full_list_file}
			fi
		fi
		note=
	done < <(cat ${tf})
done

echo
echo "Done, see: ${full_list_file}"
