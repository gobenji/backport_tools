#!/bin/bash

FILEHASH=$1; shift

if [ ! -e "${FILEHASH}" ]; then
	echo "list file doesn't exist at: ${FILEHASH}" >&2
	exit 1
fi

# final sorted list of commit ids
patchlisttmpfile=$(mktemp)

function sort_commit_file_by_authordate() {
	# file contains "commitdate commitid authordate"
	sort -k3 -n $1 -o $1
	cat $1 | awk ' { print $1" "$2 } ' >> $sortresultfile
	# delete the prev_commitdate.dups file
	rm -f $1
}

function sort_commit_list() {
	sort -k1 -n $_patchlisttmpfile -o $_patchlisttmpfile

	_num=$(cat $_patchlisttmpfile | wc -l)
	_sort_num=$(cat $_patchlisttmpfile | awk ' { print $1 } ' | sort -u | wc -l)
	[ $_num == $_sort_num ] && return 0

	sortresultfile=$(mktemp)
	prev_cdatefile=/tmp/1.dups
	# go through the file line by line
	cat $_patchlisttmpfile | while read LINE
	do
		local _cdate=$(echo $LINE | awk ' { print $1 } ')
		local _cid=$(echo $LINE | awk ' { print $2 } ')
		local _adate=$(git log --pretty=%at -1 $_cid)

		# Does _cdate.dups exist?
		cdatefile=/tmp/${_cdate}.dups
		if [ -e $cdatefile ]; then
			# Yes, add this data to it
			echo "$_cdate $_cid $_adate" >> $cdatefile
		else
			# No, create a new _cdate.dups file and echo this data into it
			echo "$_cdate $_cid $_adate" > $cdatefile
			# does prev_cate.dups file exist?
			if [ -e $prev_cdatefile ]; then
				sort_commit_file_by_authordate $prev_cdatefile
			fi
		fi
			prev_cdatefile=$cdatefile
	done

	# finish the last one
	last_cdate=$(tail -1 $_patchlisttmpfile | awk ' { print $1 } ')
	sort_commit_file_by_authordate "/tmp/${last_cdate}.dups"

	mv -f $sortresultfile $_patchlisttmpfile
}

# temp file for sorting
_patchlisttmpfile=$(mktemp)

# re-sort the patches by date
while read LINE; do
	case "$LINE" in
		\#)
			continue
			;;
		^\s*$)
			continue
			;;
	esac
	HASH=`echo $LINE | awk -F " " ' { print $1 } ' `
	# is this an empty line?
	[ -z $HASH ] && continue
	# is this a comment?
	[[ $HASH == \#* ]] && continue
	_date=`git log -1 --pretty=%ct $HASH`
	echo $_date $HASH  >> $_patchlisttmpfile
done < $FILEHASH

# sort the commits according to commit date
sort_commit_list

cat $_patchlisttmpfile | awk -F " " ' { print $2 }' >> $patchlisttmpfile
mv $patchlisttmpfile $_patchlisttmpfile

# add commit message to lines
while read LINE; do
	case "$LINE" in
		\#)
			continue
			;;
		^\s*$)
			continue
			;;
	esac
	HASH=`echo $LINE | awk -F " " ' { print $1 } ' `
	# is this an empty line?
	[ -z $HASH ] && continue
	# is this a comment?
	[[ $HASH == \#* ]] && continue
	info=$(git log -1 --pretty=format:"%h %s" $HASH)
	echo "$info"
	echo "$info" >> $patchlisttmpfile
done < $_patchlisttmpfile

rm $_patchlisttmpfile
echo
echo "See: $patchlisttmpfile"
