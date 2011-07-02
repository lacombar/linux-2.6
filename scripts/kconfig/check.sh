#!/bin/sh
#

set -e

check_gettext()
{

	echo '
	#include <libintl.h>
	int main()
	{
		gettext("");
		return 0;
	}' | \
	{
		$* -xc -o /dev/null - > /dev/null 2>&1 || \
			echo HOST_EXTRACFLAGS	+= -DKBUILD_NO_NLS >> ${obj}/.tmp_check
	}
}

check_gtk()
{
	local cflags=""
	local libs=""

	if pkg-config --exists gtk+-2.0 gmodule-2.0 libglade-2.0; then
		if ! pkg-config --atleast-version=2.0.0 gtk+-2.0; then
			echo "*"
			echo "* GTK+ is present but version >= 2.0.0 is required."
			echo "*"
			false
		fi
	else
		echo "*"
		echo "* Unable to find the GTK+ installation. Please make sure that"
		echo "* the GTK+ 2.0 development package is correctly installed..."
		echo "* You need gtk+-2.0, glib-2.0 and libglade-2.0."
		echo "*"
		false
	fi

	cflags="$(pkg-config --cflags gtk+-2.0 gmodule-2.0 libglade-2.0)"
	libs="$(pkg-config --libs gtk+-2.0 gmodule-2.0 libglade-2.0)"

	echo "HOSTCFLAGS_gconf.o	+= $cflags" >> ${obj}/.tmp_check
	echo "HOSTLOADLIBES_gconf	+= $libs"   >> ${obj}/.tmp_check
}

check_ncurses()
{
	local cflags=""
	local libs=""

	ncurses_h="ncursesw/curses.h ncurses/ncurses.h ncurses/curses.h"
	ncurses_h="${ncurses_h} ncurses.h curses.h"

	for header in ${ncurses_h}; do
		if echo "#include <${header}>" | \
		    $HOSTCC -xc -E -c -o /dev/null - 2> /dev/null; then
			cflags="-DCURSES_LOC=\"<$header>\""
			break
		fi
	done

	if [ -z "$cflags" ]; then
		echo "  *"
		echo "  * Unable to find the required ncurses header files."
		echo "  * "
		echo "  * Please install ncurses (ncurses-devel) and try again."
		echo "  *"
		false
	fi

	for ext in so a dylib ; do
		for lib in ncursesw ncurses curses; do
			filename="$($HOSTCC -print-file-name=lib${lib}.${ext})"
			if [ "$filename" != "lib${lib}.${ext}" ]; then
				libs=-l$lib
				break
			fi
		done
		[ -n "$libs" ] && break
	done

	if [ -z "$libs" ]; then
		echo "  * Unable to find the required ncurses library."
		echo "  *"
		echo "  * Please install ncurses (ncurses-devel) and try again."
		echo "  * "
		false
	fi

	echo "HOSTCFLAGS	+=$cflags" >> ${obj}/.tmp_check
	echo "HOSTLOADLIBES_mconf	+= $libs"   >> ${obj}/.tmp_check
	echo "HOSTLOADLIBES_nconf	+= $libs"   >> ${obj}/.tmp_check
}

check_qt()
{
	local cflags=""
	local libs=""
	local prefix=""

	if pkg-config --exists QtCore 2> /dev/null; then
		cflags="$(pkg-config QtCore QtGui Qt3Support --cflags)"
		libs="$(pkg-config QtCore QtGui Qt3Support --libs)"
		prefix="$(pkg-config QtCore --variable=prefix)"
	else
		echo "* Unable to find the QT4 tool qmake. Trying to use QT3"
		pkg=""
		pkg-config --exists qt 2> /dev/null && pkg=qt
		pkg-config --exists qt-mt 2> /dev/null && pkg=qt-mt
		if [ -n "$pkg" ]; then
			cflags="$(pkg-config $pkg --cflags)"
			libs="$(pkg-config $pkg --libs)"
			prefix="$(pkg-config $pkg --variable=prefix)"
		else
			for d in $QTDIR /usr/share/qt* /usr/lib/qt*; do
				if [ -f $d/include/qconfig.h ]; then
					prefix=$d
					break
				fi
			done
			if [ -z "$prefix" ]; then
				echo "  *"
				echo "  * Unable to find any QT installation. Please make sure that"
				echo "  * the QT4 or QT3 development package is correctly installed and"
				echo "  * either qmake can be found or install pkg-config or set"
				echo "  * the QTDIR environment variable to the correct location."
				echo "  *"
				false
			fi
			libpath=$dir/lib
			lib=qt
			osdir=""
			${HOSTCXX} -print-multi-os-directory > /dev/null 2>&1 && \
			    osdir=x$(${HOSTCXX} -print-multi-os-directory)
			test -d $libpath/$osdir && libpath=$libpath/$osdir
			test -f $libpath/libqt-mt.so && lib=qt-mt
			cflags="-I$prefix/include"
			libs="-L$libpath -Wl,-rpath,$libpath -l$lib"
		fi
	fi

	if [ -x $prefix/bin/moc ]; then
		moc=$prefix/bin/moc
	elif [ -a -x /usr/bin/moc ]; then
		echo "  *"
		echo "  * Unable to find $prefix/bin/moc, using /usr/bin/moc instead."
		echo "  *"
		moc="/usr/bin/moc"
	fi

	echo "HOSTCXXFLAGS_qconf.o	+= $cflags" >> ${obj}/.tmp_check
	echo "HOSTLOADLIBES_qconf	+= $libs"   >> ${obj}/.tmp_check
	echo "HOSTMOC	:= $moc" >> ${obj}/.tmp_check
}

rm -f ${obj}/.tmp_check

for arg in $*; do
	case $arg in
	gettext)	;;
	gtk)		;;
	ncurses)	;;
	qt)		;;
	*)
		echo "  *"
		echo "  * Do not know how to check for \`$arg'"
		echo "  *"
		false
		;;
	esac
	echo "  CHECK   $arg"

	check_$arg
	echo "KCONFIG_CHECKED_$arg := 1"	>> ${obj}/.tmp_check
done
