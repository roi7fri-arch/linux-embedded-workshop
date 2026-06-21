#! /bin/bash -e
# Helper script to assemble and compile the U-Boot sources for the ADLINK
# LEC-iMX6 from the various source packages / patches.  Directly running
# it on the ARM should be possible, but the more practial way is to use some
# host PC with a cross-compiler.
# This script is also meant to document the steps involved, therefore we tried
# to keep it simple.						--JR01/2015
# (C)2015-2017 LiPPERT ADLINK Technology GmbH, released under the GNU GPLv2

# U-Boot as compiled by this script consists of the following source packages.
# Upon changing a component don't forget to rename this script incrementing its
# overall version number.  SRC_FSL_BASE and SRC_ADLINK are mandatory, the other
# 2 are optional.
SRC_FSL_BASE=uboot-imx-rel_imx_3.10.53_1.1.0_ga.tar.xz
SRC_FSL_GIT=uboot-imx-rel_imx_3.10.53_1.1.0_ga_git1.tar.xz
SRC_ADLINK=uboot_LEC-iMX6_8.tar.xz	# filenames in current dir only, no '/'
#SRC_CUSTOM=uboot_mypatches_1.tar.xz # also rename this script to change pkg name

#
# Some setup
#
# These are the only globals, all other variables are only used in the section
# where they appear.
BUILDDIR="${0##*/}"; BUILDDIR="${BUILDDIR%.sh}" # name of script without .sh
VERSION="_${BUILDDIR##*_}" # overall version number, taken from name of this script
test "$VERSION" = "_uboot" &&VERSION="" # no version number (development)
OUTFILE="u-boot_LEC-iMX6?-?G$VERSION.imx" # end results
# Count number of CPU cores, for make -j
CORES="$(nproc 2>/dev/null ||grep -c '^processor[ 	]*:' /proc/cpuinfo)"
test "$CORES" -ge 1 || CORES=1
# If we're running on a terminal (and not piped to a logfile or so) then use
# some escape sequences to make things look pretty.
COLOR=''; ERROR=''; NORMAL=''
if [ -t 1 ]; then
	COLOR='\e[32;1m'; ERROR='\e[31;1m'; NORMAL='\e[0m'
	clear
fi

#
# Check tools
#
echo -e "${COLOR}Before we begin I'll look for some tools I'm going to need:${NORMAL}"
if [ -n "$CROSS_COMPILE" ]; then # already set by caller of this script?
	export CROSS_COMPILE # caller wants to override default
else
	UNAME="$(uname -m)" # running natively or cross-compiling?
	test "${UNAME#arm}" = "$UNAME" && CROSS_COMPILE="arm-linux-gnueabihf-" # U-Boot's default
	# no export, default CROSS_COMPILE is only used in this section
fi
MISSING=0
while read -r TOOL COMMENT; do
	if which "$TOOL" >/dev/null 2>&1; then
		echo " - $TOOL found"
	else
		echo -e " - ${ERROR}$TOOL missing${NORMAL}: $COMMENT"
		let ++MISSING
	fi
done <<-EOL	# list of needed tools
	unxz			uncompresses XZ archives
	patch			applies changes defined by 'diff' or 'patch' files
	make			controls compilation according to defined dependencies
	sed			allows scripted editing of text
	${CROSS_COMPILE}gcc	GCC (cross) compiler for Freescale i.MX6 CPUs (ARMv7-A)
EOL
echo
if [ $MISSING != 0 ]; then
	echo "Please install the missing program(s) and try again."
	exit 1
fi
unset UNAME MISSING TOOL COMMENT # just to make it clear these are locals

#
# Uncompress the source packages to the build directory.  If this has already
# happened then we skip these steps to avoid overwriting manual changes the
# user may have made.
#
if ! cd "$BUILDDIR" 2>/dev/null; then

	#
	# Check packages
	#
	echo -e "${COLOR}Next I'll check the list of needed source packages:${NORMAL}"
	MISSING=0
	while read -r PACKAGE COMMENT; do
		# If a variable is unset the next word in line takes its place.  It's the same
		# word for all optional vars; skip line in this case.  Yes, this is nasty.
		test "$PACKAGE" = "Patches" && continue
		if [ -r "$PACKAGE" ]; then
			echo " - $PACKAGE found"
		else
			echo -e " - ${ERROR}$PACKAGE missing${NORMAL}: $COMMENT"
			let ++MISSING
		fi
	done <<-EOL	# list of needed packages
		$SRC_FSL_BASE	Freescale U-Boot sources from http://git.freescale.com/git/cgit.cgi/imx/uboot-imx.git/snapshot/${SRC_FSL_BASE%xz}gz, just recompressed
		$SRC_FSL_GIT	Patches in Freescale GIT http://git.freescale.com/git/cgit.cgi/imx/uboot-imx.git/log/?h=imx_v2014.04_3.10.53_1.1.0_ga after the tagged release
		$SRC_ADLINK	ADLINK adaptions for the LEC-iMX6 (all variants)
		$SRC_CUSTOM	Patches implementing custom changes
	EOL
	echo
	if [ $MISSING != 0 ]; then
		echo "All files need to be present in the current directory.  You can get all"
		echo "packages from the ADLINK homepage or ADLINK support."
		exit 1
	fi

	#
	# Extract sources
	#
	echo -e "${COLOR}Now I'll extract and assemble the sources.  This might take a moment ...${NORMAL}"
	mkdir "$BUILDDIR"
	cd "$BUILDDIR"
	echo " - Freescale's sources"
	tar --strip 1 -xJf "../$SRC_FSL_BASE"
	if [ -n "$SRC_FSL_GIT" ]; then
		echo " - post-release patches"
		tar -xOJf "../$SRC_FSL_GIT" | patch -sZfp1
	fi
	# At this point we have Freescale's original sources.
	echo " - ADLINK patches"
	tar -xOJf "../$SRC_ADLINK" | patch -sZfp1
	if [ -n "$SRC_CUSTOM" ]; then
		echo " - custom changes"
		tar -xOJf "../$SRC_CUSTOM" | patch -sZfp1
	fi
	if [ -n "$VERSION" ]; then
		echo " - version string: v${VERSION#_}"
		sed -i "s/^\\(EXTRAVERSION =\\).*\$/\\1 \\\\ v${VERSION#_}/" Makefile
	fi
	echo

fi # ! cd "$BUILDDIR"

#
# Compile
#
echo -e "${COLOR}Fine, now relax a bit, this will take a little while ...${NORMAL}"
rm -f ../$OUTFILE # delete output from previous run, just to be sure
build() {
	make distclean # make may fail if tree not clean
	make lec-imx6${1}g_config
	make -j $CORES
	if [ -r SPL -a ! -e u-boot.imx ]; then
		# SPL is only used for VERY early (pre-RAM!) debugging, not for
		# normal builds.  So this is mainly to document how it's done.
		cp SPL u-boot.imx
		dd if=u-boot.bin bs=1k seek=63 of=u-boot.imx
	fi
	cp u-boot.imx "../${OUTFILE/\?-\?/$1}"
}
build q-1 # Quad/Dual, 1 GB RAM variant from boards.cfg
build q-2 # Quad/Dual, 2 GB
build s-1 # Solo/DualLite, 1 GB
build s-2 # DualLite, 2 GB
echo
cd ..

#
# Bye
#
echo -e "${COLOR}Wake up, I'm done!  '$OUTFILE' contain the U-Boot"
echo -e "images - try not to brick your board, will you?  Unless you're planning to"
echo -e "recompile you may delete the work directory '$BUILDDIR/' now.${NORMAL}"
