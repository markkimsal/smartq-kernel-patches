#! /bin/bash

#############################################################################
# Copyright (c) 2003-2005,2007-2009 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#############################################################################

source $(dirname $0)/config.sh
source $(dirname $0)/wd-functions.sh

fuzz="-F0"

usage() {
    echo "SYNOPSIS: $0 [-qv] [--symbol=...] [--dir=...] [last-patch-name] [--fuzz=NUM]"
    exit 1
}

# Allow to pass in default arguments via SEQUENCE_PATCH_DEF_ARGS.
set -- $SEQUENCE_PATCH_ARGS "$@"

options=$(getopt -o qvd:F: --long quilt,symbol:,dir:,fuzz: -- "$@")

if [ $? -ne 0 ]
then
    usage
fi

eval set -- "$options"

QUIET=1
EXTRA_SYMBOLS=
CLEAN=1

while true; do
    case "$1" in
    	-q)
	    QUIET=1
	    ;;
    	-v)
	    QUIET=
	    ;;
	--quilt)
	    CLEAN=
	    ;;
	-d|--dir)
	    SCRATCH_AREA=$2
	    shift
	    ;;
	-F|--fuzz)
	    fuzz="-F$2"
	    shift
	    ;;
	--)
	    shift
	    break ;;
	*)
	    usage ;;
    esac
    shift
done

unset LIMIT
if [ $# -ge 1 ]; then
    LIMIT=$1
    shift
fi

if [ $# -ne 0 ]; then
    usage
fi

# Some patches require patch 2.5.4. Abort with older versions.
PATCH_VERSION=$(patch -v | sed -e '/^patch/!d' -e 's/patch //')
case $PATCH_VERSION in
    ([01].*|2.[1-4].*|2.5.[1-3])  # (check if < 2.5.4)
	echo "patch version $PATCH_VERSION found; " \
	     "a version >= 2.5.4 required." >&2
	exit 1
    ;;
esac

# Check SCRATCH_AREA.
if [ -z "$SCRATCH_AREA" ]; then
    echo "SCRATCH_AREA not defined (defaulting to \"tmp\")"
    SCRATCH_AREA=tmp
fi
if [ ! -d "$SCRATCH_AREA" ]; then
    if ! mkdir -p $SCRATCH_AREA; then
	echo "creating scratch dir $SCRATCH_AREA failed"
	exit 1
    fi
fi

[ "${SCRATCH_AREA:0:1}" != "/" ] \
    && SCRATCH_AREA="$PWD/$SCRATCH_AREA"

TMPDIR=$SCRATCH_AREA
export TMPDIR
ORIG_DIR=$SCRATCH_AREA/linux-$SRCVERSION.orig
TAG=$(get_branch_name)
TAG=${TAG//\//_}
PATCH_DIR=$SCRATCH_AREA/linux-$SRCVERSION${TAG:+-$TAG}
PATCH_LOG=$SCRATCH_AREA/patch-$SRCVERSION${TAG:+-$TAG}.log
LAST_LOG=$SCRATCH_AREA/last-$SRCVERSION${TAG:+-$TAG}.log

# Check if we can clean up backup files at the end
# (slightly faster, but requires more disk space).
free_blocks="$(df -P "$SCRATCH_AREA" \
    | awk 'NR==2 && match($4, /^[0-9]*$/) { print $4 }' 2> /dev/null)"
[ "0$free_blocks" -gt 262144 ] && enough_free_space=1

if [ ! -d $ORIG_DIR ]; then
    # Check if linux-$SRCVERSION.tar.gz is accessible.
    for file in {$SCRATCH_AREA/,,}linux-$SRCVERSION.tar.{gz,bz2}; do
	if [ -r $file ]; then
	    LINUX_ORIG_TARBALL=$file
	    [ ${file:(-3)} = .gz  ] && COMPRESS_MODE=z
	    [ ${file:(-4)} = .bz2 ] && COMPRESS_MODE=j
	    break
	fi
    done
    if [ -z "$LINUX_ORIG_TARBALL" ]; then
        if type ketchup 2>/dev/null; then
	    pushd . > /dev/null
	    cd $SCRATCH_AREA && \
	    rm -rf linux-$SRCVERSION && \
	    mkdir linux-$SRCVERSION && \
	    cd linux-$SRCVERSION && \
	    ketchup $SRCVERSION && \
	    cd $SCRATCH_AREA && \
	    mv linux-$SRCVERSION linux-$SRCVERSION.orig
	    popd > /dev/null
	fi
	if [ ! -d "$ORIG_DIR" ]; then
	    echo "Kernel source archive \`linux-$SRCVERSION.tar.gz' not found," >&2
	    echo "alternatively you can put an unpatched kernel tree to" >&2
	    echo "$ORIG_DIR." >&2
	    exit 1
	fi
    fi
fi

# Check series
if [ ! -r series ]; then
    echo "Configuration file \`series' not found"
    exit 1
fi
if [ -e scripts/check-patches ]; then
    scripts/check-patches || {
	echo "Inconsistencies found."
	echo "Please clean up series.conf and/or the patches directories!"
	read
    }
fi

echo "Creating tree in $PATCH_DIR"

# Clean up from previous run
rm -f "$PATCH_LOG" "$LAST_LOG"
if [ -e $PATCH_DIR ]; then
    tmpdir=$(mktemp -d ${PATCH_DIR%/*}/${0##*/}.XXXXXX)
    if [ -n "$tmpdir" ]; then
	echo "Cleaning up from previous run (background)"
	mv $PATCH_DIR $tmpdir
	rm -rf $tmpdir &
    else
	echo "Cleaning up from previous run"
	rm -rf $PATCH_DIR
    fi
fi

# Create fresh $SCRATCH_AREA/linux-$SRCVERSION.
if ! [ -d $ORIG_DIR ]; then
    echo "Extracting $LINUX_ORIG_TARBALL"
    tar xf$COMPRESS_MODE $LINUX_ORIG_TARBALL --directory $SCRATCH_AREA
    if [ -e $SCRATCH_AREA/linux-$SRCVERSION ]; then
	mv $SCRATCH_AREA/linux-$SRCVERSION $ORIG_DIR || exit 1
    elif [ -e $SCRATCH_AREA/linux ]; then
	# Old kernels unpack into linux/ instead of linux-$SRCVERSION/.
	mv $SCRATCH_AREA/linux $ORIG_DIR || exit 1
    fi
    find $ORIG_DIR -type f | xargs chmod a-w,a+r
fi

# The rc patch
RC_PATCH=
SPEC_FILE=$(dirname $0)/../kernel.spec
RELEASED=$(cat ${SPEC_FILE} | sed -e '/^%define released_kernel/!d')
RELEASED=${RELEASED##* }
if [ $RELEASED -eq 0 ]; then
    SUBLEVEL=$(cat ${SPEC_FILE} | sed -e '/^%define base_sublevel/!d')
    SUBLEVEL=${SUBLEVEL##* }

    RCREV=$(cat ${SPEC_FILE} | sed -e '/^%define rcrev/!d')
    RCREV=${RCREV##* }

    RC_PATCH=patch-2.6.$(expr $SUBLEVEL + 1)-rc${RCREV}.bz2
else
    RC_PATCH=
fi

PATCHES=( ${RC_PATCH} \
 $(cat series | sed -e '/^#/d' -e '/^$/d' -e 's/^/patches\//' | tr '\n' ' ') )

# Check if patch $LIMIT exists
if [ -n "$LIMIT" ]; then
    for ((n=0; n<${#PATCHES[@]}; n++)); do
	if [ "$LIMIT" = - ]; then
	    LIMIT=${PATCHES[n]}
	    break
	fi
	case "${PATCHES[n]}" in
	$LIMIT|*/$LIMIT)
	    LIMIT=${PATCHES[n]}
	    break
	    ;;
	esac
    done
    if ((n == ${#PATCHES[@]})); then
	echo "No patch \`$LIMIT' found."
	exit 1
    fi
    PATCHES_BEFORE=()
    for ((m=0; m<n; m++)); do
	PATCHES_BEFORE[m]=${PATCHES[m]}
    done
    PATCHES_AFTER=()
    for ((m=n; m<${#PATCHES[@]}; m++)); do
	PATCHES_AFTER[m-n]=${PATCHES[m]}
    done
else
    PATCHES_BEFORE=( "${PATCHES[@]}" )
    PATCHES_AFTER=()
fi

# Helper function to restore files backed up by patch. This is
# faster than doing a --dry-run first.
restore_files() {
    local backup_dir=$1 patch_dir=$2 file wd=$PWD
    local -a remove restore
 
    if [ -d $backup_dir ]; then
	pushd $backup_dir > /dev/null
	for file in $(find . -type f) ; do
	    if [ -s "$file" ]; then
		restore[${#restore[@]}]="$file"
	    else
		remove[${#remove[@]}]="$file"
	    fi
	done
	#echo "Restore: ${restore[@]}"
	[ ${#restore[@]} -ne 0 ] \
	    && printf "%s\n" "${restore[@]}" \
		| xargs cp -f --parents --target $patch_dir
	cd $patch_dir
	#echo "Remove: ${remove[@]}"
	[ ${#remove[@]} -ne 0 ] \
	    && printf "%s\n" "${remove[@]}" | xargs rm -f
	popd > /dev/null
    fi
}

# Create hardlinked source tree
echo "Linking from $ORIG_DIR"
cp -rld $ORIG_DIR $PATCH_DIR

echo -e "# Symbols: $SYMBOLS\n#" > $PATCH_DIR/series
SERIES_PFX=
if [ -n "$CLEAN" ]; then
    SERIES_PFX="# "
fi

mkdir $PATCH_DIR/.pc
echo 2 > $PATCH_DIR/.pc/.version

# Patch kernel
set -- "${PATCHES[@]}"
while [ $# -gt 0 ]; do
    PATCH="$1"
    if [ "$PATCH" = "$LIMIT" -a -n "$CLEAN" ]; then
	STEP_BY_STEP=1
	echo "Stopping before $PATCH"
    fi
    if [ -n "$STEP_BY_STEP" ]; then
	while true; do
	    echo -n "Continue ([y]es/[n]o/yes to [a]ll)?"
	    read YESNO
	    case $YESNO in
		([yYjJsS])
		    break
		    ;;
		([nN])
		    break 2	# break out of outer loop
		    ;;
		([aA])
		    unset STEP_BY_STEP
		    break
		    ;;
	    esac
	done
    fi

    if [ ! -r "$PATCH" ]; then
	echo "Patch $PATCH not found."
	status=1
	break
    fi
    echo "[ $PATCH ]"
    echo "[ $PATCH ]" >> $PATCH_LOG
    backup_dir=$PATCH_DIR/.pc/$PATCH

    exec 5<&0  # duplicate stdin
    case $PATCH in
    *.gz)	exec < <(gzip -cd $PATCH) ;;
    *.bz2)	exec < <(bzip2 -cd $PATCH) ;;
    *)		exec < $PATCH ;;
    esac
    patch -d $PATCH_DIR --backup --prefix=$backup_dir/ -p1 -E $fuzz \
	    --no-backup-if-mismatch > $LAST_LOG 2>&1
    STATUS=$?
    exec 0<&5  # restore stdin
    
    [ $STATUS -ne 0 ] \
	&& restore_files $backup_dir $PATCH_DIR
    [ -n "$CLEAN" -a -z "$enough_free_space" ] \
	&& rm -rf $PATCH_DIR/.pc/
    cat $LAST_LOG >> $PATCH_LOG
    [ -z "$QUIET" ] && cat $LAST_LOG
    if [ $STATUS -ne 0 ]; then
	[ -n "$QUIET" ] && cat $LAST_LOG
	echo "Patch $PATCH failed (rolled back)."
	echo "Logfile: $PATCH_LOG"
	status=1
	break
    else
	echo "$SERIES_PFX$PATCH" >> $PATCH_DIR/series
	[ -z "$CLEAN" ] \
	    && echo "$PATCH" >> $PATCH_DIR/.pc/applied-patches
	rm -f $LAST_LOG
    fi

    shift
    if [ "$PATCH" = "$LIMIT" -a -z "$CLEAN" ]; then
	break
    fi
done

[ -n "$CLEAN" -a -n "$enough_free_space" ] \
    && rm -rf $PATCH_DIR/.pc/

if [ -n "$CLEAN" ]; then
    rm $PATCH_DIR/series
fi

ln -s $PWD $PATCH_DIR/patches
ln -s patches/scripts/refresh_patch.sh $PATCH_DIR/refresh_patch.sh
if [ -z "$CLEAN" ]; then
  [ -r $HOME/.quiltrc ] && . $HOME/.quiltrc
  [ ${QUILT_PATCHES-patches} != patches ] \
    && ln -s $PWD $PATCH_DIR/${QUILT_PATCHES-patches}
fi
# If there are any remaining patches, add them to the series so
# they can be fixed up with quilt (or similar).
if [ -n "$*" ]; then
    ( IFS=$'\n' ; echo "$*" ) >> $PATCH_DIR/series
fi

echo "[ Tree: $PATCH_DIR ]"

[ $# -gt 0 ] && exit $status
