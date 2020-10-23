#!/bin/sh
#Local checking. Creates pkg/
. version
sbin/gendoc.sh #Ensure History file is uptodate
/usr/local/bin/rake --trace gem

