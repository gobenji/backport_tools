#!/bin/bash
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
. ${SCRIPTPATH}/config.sh

pdir=${1:-patches}
cids=${cids:-""}

#BRANCHES=${BRANCHES:-"origin/master net-next/master net/master rdma/for-next rdma/for-rc i2c/i2c/for-current i2c/i2c/for-next"}
BRANCHES=${BRANCHES:-"origin/master net-next/main net/main rdma/for-next rdma/for-rc"}
#
# Expected branches configured at your upstream linux git tree
#
#$ cat .git/config 
#[core]
#        repositoryformatversion = 0
#        filemode = true
#        bare = false
#        logallrefupdates = true
#[branch "master"]
#[remote "rdma"]
#        url = git://git.kernel.org/pub/scm/linux/kernel/git/rdma/rdma.git
#        fetch = +refs/heads/*:refs/remotes/rdma/*
#[remote "net-next"]
#        url = git://git.kernel.org/pub/scm/linux/kernel/git/davem/net-next.git
#        fetch = +refs/heads/*:refs/remotes/net-next/*
#[remote "net"]
#        url = git://git.kernel.org/pub/scm/linux/kernel/git/davem/net.git
#        fetch = +refs/heads/*:refs/remotes/net/*
#[remote "origin"]
#        url = git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
#        fetch = +refs/heads/*:refs/remotes/origin/*
#[branch "rdma-for-next"]
#        remote = rdma
#        merge = refs/heads/for-next
#[branch "net-next-master"]
#        remote = net-next
#        merge = refs/heads/master

if [ "X${cids}" == "X" ]; then
	pdir=$(readlink -f ${pdir})
	if [ ! -e "${pdir}" ]; then
		echo "-E- patches folder does not exit !" >&2
		exit 1
	fi

	echo "Working with: ${pdir}"
fi
echo

cd ${TREE}
git remote update
cid_to_scan=

echo "Getting short commid IDs..."
if [ "X${cids}" == "X" ]; then
	for pp in $(grep "^[0-9]" ${pdir}/series)
	do
		#	echo "${pp}"
		cid=
		if echo "${pp}" | grep -Eq '^[0-9]+-[a-zA-Z0-9]+.(diff|patch)'; then
			cid=$(echo ${pp} | sed -r -e 's/.*-(.*).(diff|patch)/\1/g')
		fi
		if [ "X${cid}" == "X" ]; then
			cid=$(grep "imported from commit" ${pdir}/${pp} | sed -e 's/.*commit //g' -e 's/).*//g')
		fi
		if [ "X${cid}" == "X" ]; then
			cid=$(grep "^commit " ${pdir}/${pp} | cut -d" " -f2)
		fi
		if [ "X${cid}" == "X" ]; then
			cid=$(grep "^From " ${pdir}/${pp} | cut -d" " -f2)
		fi
		if [ "X${cid}" == "X" ]; then
			echo "Failed to get commit ID of $pp (${subj}) !" >&2
			continue
		#	exit 1
		fi
		cur_patch=$(git log -1 --oneline --decorate ${cid} 2>/dev/null)
		if [ "X${cur_patch}" == "X" ]; then
			echo "-E- Failed to find '${cid}' in git log!" >&2
			continue
		#	exit 1
		fi
		cid_short=$(git log -1 --format="%h" ${cid})
		if !(echo -e "${cid_to_scan}" | grep -qw "${cid_short}"); then
			cid_to_scan="${cid_to_scan} ${cid_short}"
		fi
	done
else
	for cid in ${cids}
	do
		cur_patch=$(git log -1 --oneline --decorate ${cid} 2>/dev/null) 
		if [ "X${cur_patch}" == "X" ]; then
			echo "-E- Failed to find '${cid}' in git log!" >&2
			continue
			exit 1
		fi
		cid_short=$(git log -1 --format="%h" ${cid})
		if !(echo -e "${cid_to_scan}" | grep -qw "${cid_short}"); then
			cid_to_scan="${cid_to_scan} ${cid_short}"
		fi
	done
fi

echo "Searching for relevant fixes..."
for cid_short in ${cid_to_scan}
do
#	echo "${pp}"
	cur_patch=$(git log -1 --oneline --decorate ${cid_short} 2>/dev/null)
	fixes=$(git log --format="%h" -i --grep "fixes:.*${cid_short}" ${BRANCHES})
	fixes_missing=
	if [ "X${fixes}" != "X" ]; then
		for cid in ${fixes}
		do
			if !(echo -e "${cid_to_scan}" | grep -qw "${cid}"); then
				fixes_missing="${fixes_missing} ${cid}"
			fi
		done
	fi

	cur_patch_sub=$(git log -1 --format="%s" ${cid_short} 2>/dev/null)
	fixes=$(git log --format="%h" -i --grep "fixes:.*${cur_patch_sub}" ${BRANCHES})
	if [ "X${fixes}" != "X" ]; then
		for cid in ${fixes}
		do
			if !(echo -e "${cid_to_scan}" | grep -qw "${cid}") && !(echo -e "${fixes_missing}" | grep -qw "${cid}"); then
				fixes_missing="${fixes_missing} ${cid}"
			fi
		done
	fi

	if [ "X${fixes_missing}" != "X" ]; then
		echo "Patch we applied:"
		echo "${cur_patch}"
		echo
		echo "Fixes for this patch:"
		for cid in ${fixes_missing}
		do
			git log -1 --oneline --decorate ${cid} 2>/dev/null
		done
		echo "--------------------------------------------------"
	fi
done
