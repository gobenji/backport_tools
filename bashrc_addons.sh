# load this file from your ~/.bashrc file

__SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
PATH=$PATH:${__SCRIPTPATH}/
unset __SCRIPTPATH

alias quilt_edit_series='vim patches/series'
alias _clean_rej='find . -name "*rej" -exec \rm -fv '{}' \;'
alias show_rej='find . -name "*rej"'

# for the note in the commit message
alias show_conflicted_files='echo "Conflicts:"; find . -name "*rej" | xargs -IXX echo XX | sed -e "s/.rej//g" -e "s/^\.\// - /g"'

unalias quilt_pop &>/dev/null
unalias quilt_pop_one &>/dev/null
unalias quilt_push &>/dev/null
unalias quilt_push_one &>/dev/null
unalias git_apply_quilt_series &>/dev/null
unalias quilt_refresh &>/dev/null
unalias make_mlx_mods &>/dev/null

function quilt_pop()
{
	_clean_rej
	quilt pop -af
}

function quilt_pop_one
{
	_clean_rej
	quilt pop -f
}

function quilt_confirm_file_list()
{
	local no_verify=${1:-0}
	local got_issues=0

	if [ $no_verify -eq 0 ]; then
		echo -e "\nVerifying that all rejected files are tracked by this quilt patch in order not to loose the fix..."
	fi

	local missing_files=""
	local lastpatch=$(quilt applied | tail -1)
	if [ "X${lastpatch}" == "X" ]; then
		return
	fi
	echo "Current patch: ${lastpatch}"
	grep "Subject: " patches/${lastpatch}
	for fname in $(cat patches/${lastpatch} | diffstat -K -q -l -p1)
	do
		if [ ! -e "${fname}" ]; then
			# make sure it wasn't removed by this patch
			if grep -A1 -- "--- a/${fname}" patches/${lastpatch} | grep -- "+++ /dev/null" &>/dev/null; then
				continue
			fi
			echo "WARNING: Patch wants to modify a MISSING file: '${fname}'" >&2
			missing_files="${fname}\n${missing_files}"
		fi
	done

	local reject_files=$(find . -name "*rej")
	if [ $no_verify -eq 0 ]; then
		for fname in $reject_files
		do
			if ! (quilt files | grep -wq "${fname}"); then
				echo "Adding missing file: $fname ..."
				quilt add $fname
			fi
		done
		echo "Done"
	fi
	echo -e "Summary:\n"

	if [ "X${reject_files}" != "X" ]; then
		echo "Reject files to handle:" >&2
		echo -e "${reject_files}" >&2
		got_issues=1
	fi

	if [ "X${missing_files}" != "X" ]; then
		echo
		echo "!!!!!!!!!! WARNING !!!!!!!!!!" >&2
		echo "Patch wants to modify a MISSING files:" >&2
		echo -e "${missing_files}" >&2
		got_issues=1
	fi

	if [ ${got_issues} -eq 1 ]; then
		echo "" >&2
		echo "After handling all isssues, run:" >&2
		echo "1. quilt refresh" >&2
		echo "2. quilt_add_conflicts_note" >&2
	fi
}

function quilt_push()
{
	_clean_rej
	quilt push --fuzz=0 -af
	if [ $? -ne 0 ]; then
		timeout 4 quilt_check_if_backported.sh
		quilt_confirm_file_list
		/usr/bin/false
	fi
}

function quilt_push_one()
{
	_clean_rej
	quilt push --fuzz=0 -f
	if [ $? -ne 0 ]; then
		timeout 4  quilt_check_if_backported.sh
		quilt_confirm_file_list
		/usr/bin/false
	fi
}

function quilt_status()
{
	quilt_confirm_file_list 1
}

function quilt_add_conflicts_note()
{
	local lastpatch=$(quilt applied | tail -1)
	if [ "X${lastpatch}" == "X" ]; then
		return
	fi
	if grep -q "Conflicts:" patches/${lastpatch}; then
		echo "Conflicts section was already added, will open for edit only"
		sleep 1
	else
		sed '/Upstream-status:/r'<(show_conflicted_files) -i -- patches/${lastpatch}
	fi
	quilt header -e
}

function quilt_refresh()
{
	local failed=0
	for pp in $(quilt unapplied)
	do
		quilt push
		if [ $? -ne 0 ] ; then
			echo "-E- Failed to apply: $pp"
			failed=1
			break
		fi
		quilt refresh
	done
	if [ $failed -eq 1 ]; then
		/usr/bin/false
	fi
}

function git_apply_quilt_series()
{
	for pp in $(quilt unapplied)
	do
		git am -s patches/$pp
		if [ $? -ne 0 ] || [ -e ".git/rebase-apply" ]; then
			echo "-E- Failed to apply: $pp"
			break
		fi
	done
}

function quilt_refresh_and_apply_with_git()
{
	quilt_pop
	quilt_refresh && quilt_pop && git_apply_quilt_series
}

function set_patches_link()
{
	if [ "X${1}" == "X" ]; then
		echo "Path not provided !" >&2
		return
	fi
	if [ ! -e "$1" ]; then
		echo "$1 does not exist !" >&2
		return
	fi
	if [ -L "patches" ]; then
		echo "Removing existing link"
		ls -l patches
		unlink patches
	fi
	if [ -e "patches" ]; then
		echo "patches exists and it's not a link !" >&2
		return
	fi
	echo ""
	echo "Creating link patches -> $1"
	ln -s $1 patches
	echo ""
}

function adjust_config_file()
{
	set -x
	sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYS=.*/CONFIG_SYSTEM_TRUSTED_KEYS=""/g' .config
	sed -i 's/CONFIG_MODULE_SIG=y/CONFIG_MODULE_SIG=n/' .config
	sed -i 's/CONFIG_SYSTEM_DATA_VERIFICATION=y/CONFIG_SYSTEM_DATA_VERIFICATION=n/' .config
	sed -i 's/CONFIG_MODULE_SIG_FORMAT=y/CONFIG_MODULE_SIG_FORMAT=n/' .config
	sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYRING=y/CONFIG_SYSTEM_TRUSTED_KEYRING=n/' .config
	sed -i 's/CONFIG_MODULE_SIG=y/CONFIG_MODULE_SIG=n/' .config
	sed -i 's/CONFIG_CFG80211=m/CONFIG_CFG80211=n/' .config
	set +x
}

function make_mlx_mods()
{
	local flags=$1
	local pids=""

	local mods="modules"
	if echo $flags | grep -qw clean ; then
		mods=""
	fi

	make -j4 M=drivers/infiniband/core/ ${mods} -s $flags &
	pids+=" $!"
	make -j4 M=drivers/infiniband/hw/mlx5 ${mods} -s $flags &
	pids+=" $!"
	make -j4 M=drivers/infiniband/hw/mlx4 ${mods} -s $flags &
	pids+=" $!"
	make -j4 M=drivers/net/ethernet/mellanox/mlx4 ${mods} -s $flags &
	pids+=" $!"
	make -j4 M=drivers/net/ethernet/mellanox/mlx5/core ${mods} -s $flags &
	pids+=" $!"
	make -j4 M=drivers/infiniband/ulp/ipoib ${mods} -s $flags &
	pids+=" $!"

	failed=0
	for p in $pids; do
        	if wait $p; then
                	echo "Process $p success"
	        else
        	        echo "Process $p fail"
			failed=1
	        fi
	done
	if [ $failed -eq 1 ]; then
		/usr/bin/false
	fi
}

alias config_and_prep='make dist-configs && /bin/cp -f redhat/configs/*$(uname -m).config .config && adjust_config_file && make olddefconfig && make modules_prepare'
alias config_and_make='config_and_prep && make -j50 -s'
alias make_mlx_mods_Werror='make_mlx_mods '
alias make_mlx_mods_clean='make_mlx_mods clean'
