#!/bin/ksh -p
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#

#
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# ident	"%Z%%M%	%I%	%E% SMI"

#
# This test verifies that USDT providers are removed when its associated
# load object is closed via dlclose(3dl).
#

if [ $# != 1 ]; then
	echo expected one argument: '<'dtrace-path'>'
	exit 2
fi

dtrace=$1
DIR=${TMPDIR:-/tmp}/dtest.$$

mkdir $DIR
cd $DIR

cat > Makefile <<EOF
all: main livelib.so deadlib.so

main: main.o prov.o
	cc -o main main.o

main.o: main.c
	cc -c main.c


livelib.so: livelib.o prov.o
	cc -shared -o livelib.so livelib.o prov.o 

livelib.o: livelib.c prov.h
	cc -c livelib.c

prov.o: livelib.o prov.d
	$dtrace -G -s prov.d livelib.o

prov.h: prov.d
	$dtrace -h -s prov.d


deadlib.so: deadlib.o
	cc -shared -o deadlib.so deadlib.o 

deadlib.o: deadlib.c
	cc -c deadlib.c

clean:
	rm -f main.o livelib.o prov.o prov.h deadlib.o

clobber: clean
	rm -f main livelib.so deadlib.so
EOF

cat > prov.d <<EOF
provider test_prov {
	probe go();
};
EOF

cat > livelib.c <<EOF
#include "prov.h"

void
go(void)
{
	TEST_PROV_GO();
}
EOF

cat > deadlib.c <<EOF
void
go(void)
{
}
EOF


cat > main.c <<EOF
#include <windows.h>
#include <unistd.h>
#include <stdio.h>

int
main(int argc, char **argv)
{
	void *live;

	if ((live = LoadLibrary("./livelib.so")) == NULL) {
		printf("dlopen of livelib.so failed: %s\n", GetLastError());
		return (1);
	}

	(void) FreeLibrary(live);


	return (0);
}
EOF

make > /dev/null
if [ $? -ne 0 ]; then
	print -u2 "failed to build"
	exit 1
fi

script() {
	(cat <<EOF
	syscall::pause:entry
	/pid == \$target/
	{
		system("$dtrace -l -P test_prov*");
		system("kill %d", \$target);
		exit(0);
	}

	tick-1s
	/i++ == 5/
	{
		printf("failed\n");
		exit(1);
	}
EOF
) > /tmp/dtest.$$
$dtrace -w -x bufsize=1k -c ./main -qs /tmp/dtest.$$
}

script 2>&1
status=$?

cd /
/bin/rm -rf $DIR

exit $status
