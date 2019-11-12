#!/bin/bash
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

shopt -s expand_aliases
source ${SCRIPTPATH}/bashrc_addons.sh
set -e

function build
{
	set +e
	make_mlx_mods_Werror
	if [ $? -ne 0 ]; then
		make_mlx_mods_clean
		rm -f .config*
		config_and_prep
		make oldconfig
		make_mlx_mods_Werror
		if [ $? -ne 0 ]; then
			return 1
		fi
	fi
	return 0
}

# use unapplied instead of series to support resuming
tot=$(quilt series | wc -l)
for id in $(quilt unapplied); do
	cur=$(quilt series | grep -B10000 $id | wc -l)
	echo; echo; echo;
	echo " Checking patch #$cur/$tot ===== $id"
	quilt_push_one
	if [ $? -ne 0 ]; then
		echo "Fatal! Failed to apply ${id}"
		exit
	fi
	build
	if [ $? -eq 0 ]; then
		echo "succeeded ${id}"
	else
		echo "failed    ${id}"
		exit 1
	fi
done

echo; echo; echo;
echo "Done, all passed."
