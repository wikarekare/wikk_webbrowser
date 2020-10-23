#!/bin/sh
#Copy up to rubygem.org
. version
git tag -a ${VERSION} -m "Gem release ${VERSION}"
/usr/local/bin/rake release VERSION=${VERSION} #--trace

