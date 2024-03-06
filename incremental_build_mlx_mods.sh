#!/bin/bash
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

shopt -s expand_aliases
source ${SCRIPTPATH}/bashrc_addons.sh

function build
{
	local id=$1

	# refresh .config if we changed configs
	if quilt files | grep -E "Kconfig|redhat/configs" &>/dev/null ; then
		echo "The patch changes Kconfig file or redhat/configs, refreshing .config"
		/bin/rm -f .config*
		config_and_prep
	fi

	make_mlx_mods_Werror
	if [ $? -ne 0 ]; then
		echo "Failed    ${id}"
		exit 1
	fi
	echo "Succeeded ${id}"
}

echo "Checking that current tree state can compile before applying patches..."
/bin/rm -f .config*
config_and_prep
build "$(quilt applied 2>&1 | tail -1)"

# use unapplied instead of series to support resuming
tot=$(quilt series | wc -l)
for id in $(quilt unapplied); do
	cur=$(quilt series | grep -B10000 $id | wc -l)
	echo; echo; echo;
	echo " Checking patch #$cur/$tot ===== $id"
	quilt_push_one
	if [ $? -ne 0 ]; then
		echo "Fatal! Failed to apply ${id}"
		exit 1
	fi
	build "${id}"
done

echo; echo; echo;
echo "Done, all passed."
