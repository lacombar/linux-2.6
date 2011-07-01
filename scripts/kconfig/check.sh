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

rm -f ${obj}/.tmp_check

for arg in $*; do
	case $arg in
	gettext)	;;
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
