#!/bin/sh

set -e

cd /home/lavadocs/lava-docs
git fetch origin
REMOTE=$(git log -1 --format=format:%H origin/master)
HEAD=$(git log -1 --format=format:%H)

if [ "$HEAD" = "$REMOTE" ] ; then
	# nothing to do
	exit 0
fi

git checkout -- .
git clean -dff
git checkout $REMOTE
. /home/lavadocs/venv/bin/activate
make html
rsync -a --delete build/html/ /var/www/lava-docs/
