#!/bin/bash
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

shopt -s expand_aliases
source ${SCRIPTPATH}/bashrc_addons.sh
set -e

fixes_only=0
base_kver=
rhel_rel=
kvers=

usage()
{
	cat <<EOF
	$0 [options]
		--rhel-rel
		--base-kernel-version
		--kernel-versions
		--fixes-only
		--help
EOF
}

while [ "X$1" != "X" ]
do
	case "$1" in
		--rhel-rel)
			rhel_rel=$2
			shift
			;;
		--base-kernel-version)
			base_kver=$2
			shift
			;;
		--kernel-versions)
			kvers=$2
			shift
			;;
		--fixes-only)
			fixes_only=1
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			echo "Bad option: $1" >&2
			exit 1
			;;
	esac

	shift
done

if [ -e "Makefile.rhelver" ]; then
	rhver=$(git show HEAD:Makefile.rhelver | grep ^RHEL_MAJOR | sed -e s/RHEL_MAJOR\ =\ //)
else
	rhver=$(git show HEAD:Makefile | grep ^RHEL_MAJOR | sed -e s/RHEL_MAJOR\ =\ //)
fi
if [ "X${rhver}" == "X" ]; then
	echo "Can't get RHEL version!" >&2
	echo "Run me from RHEL git tree..."
	exit 1
fi
echo "Detected RHEL ${rhver} tree ..."

case "${rhver}" in
	7)
		[ "X${base_kver}" == "X" ] && base_kver='v4.17'
		rhel_tag='RHEL-7.3'
		;;
	8)
		[ "X${base_kver}" == "X" ] && base_kver='v4.18'
		rhel_tag='v4.18'
		;;
	*)
		echo "Unsupported RHEL version $rhver !" >&2
		exit 1
		;;
esac

if [ $fixes_only -eq 1 ]; then
	echo "FIXES ONLY mode"
	echo "Will not move to master branch."

	case "${rhver}" in
		7)
			rm -rf /tmp/new_fixes_rh7
			${SCRIPTPATH}/get_all_new_fixes.sh ${RHEL_7_TREE} ${rhel_tag} ${base_kver} /tmp/new_fixes_rh7
			;;
		8)
			rm -rf /tmp/new_fixes_rh8
			${SCRIPTPATH}/get_all_new_fixes.sh ${RHEL_8_TREE} ${rhel_tag} ${base_kver} /tmp/new_fixes_rh8
			;;
	esac

	exit 0
fi

if [ "X${rhel_rel}" == "X" ]; then
	echo "Must provide --rhel-rel" >&2
	exit 1
fi
if [ "X${kvers}" == "X" ]; then
	echo "Must provide --kernel-versions" >&2
	exit 1
fi

echo
echo "Updating upstream repo ${TREE}"
ORIG_DIR=$PWD
cd ${TREE}
git remote update

cd $ORIG_DIR
echo
echo "Moving to master branch..."
git checkout master

mkdir -p ~/rh_backports/kernel/rhel${rhel_rel}/full_backport
for drv in mlx4 mlx5
do
	tag_start=$base_kver
	for kver in $kvers
	do
		tag_end=$kver
		echo
		echo "Getting $drv patches from kernels ${tag_start} --> ${tag_end}"

		cd $ORIG_DIR
		python ${SCRIPTPATH}/git-change-log -o ${rhel_tag}.. -u ${tag_start}..${tag_end} --old_kernel_path . --upstream_kernel_path ${TREE} --dirs ${drv} | tee ~/rh_backports/kernel/rhel${rhel_rel}/full_backport/git-change-log-${tag_end}.${drv}

		cd ${TREE}
		/bin/rm -rf ~/rh_backports/kernel/rhel${rhel_rel}/full_backport/patches-${kver}.${drv}
		git-backport -q -b TODO_BZNUM -d ~/rh_backports/kernel/rhel${rhel_rel}/full_backport/patches-${kver}.${drv} -h ~/rh_backports/kernel/rhel${rhel_rel}/full_backport/git-change-log-${kver}.${drv}

		tag_start=$tag_end
	done
done

/bin/rm -rf ~/rh_backports/kernel/rhel${rhel_rel}/full_backport.bkp
/bin/cp -a ~/rh_backports/kernel/rhel${rhel_rel}/full_backport ~/rh_backports/kernel/rhel${rhel_rel}/full_backport.bkp

echo
echo "All at ~/rh_backports/kernel/rhel${rhel_rel}/full_backport"

