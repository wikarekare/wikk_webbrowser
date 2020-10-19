#!/bin/sh
#Copy up to rubygem.org
. lib/version
/usr/local/bin/rake release VERSION=${VERSION} #--trace

