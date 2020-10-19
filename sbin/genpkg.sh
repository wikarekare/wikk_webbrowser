#!/bin/sh
#Local checking. Creates pkg/
./gendoc.sh #Ensure History file is uptodate
/usr/local/bin/rake --trace gem

