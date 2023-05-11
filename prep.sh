#!/bin/sh
set -e

# This script will grab all dependencies & submodules, and copy their docs to our source dir.
# After running this, you can build the docs with jekyll.
# This is safe & lightweight to rerun.

ROOT=`pwd`
DOCS=$ROOT/docs
DEFAULT_SOURCE=sources
SOURCE=$DEFAULT_SOURCE

set_nav_order()
{
  FILE=$1
  ORDER=$2

  # Assume they'll have a title, because they kind of need to
  sed -i "s/^title:/nav_order: $ORDER\ntitle:/" $FILE
}

copy_docs()
{
  REPO=$1
  TARGET=$2
  ORDER=$3

  REPO_PATH=$SOURCE/$REPO
  TARGET_PATH=$DOCS/$TARGET

  if [ "$SOURCE" != "$DEFAULT_SOURCE" -a ! -d "$REPO_PATH" ]; then
    # We are pulling from another source, but it doesn't exist. Fall back to submodules.
    # User will notice without us being too noisy because we print the path below.
    REPO_PATH=$DEFAULT_SOURCE/$REPO
  fi

  echo "Copying $REPO_PATH to $TARGET"

  rm -rf $TARGET_PATH
  mkdir -p $TARGET_PATH
  cp -r $REPO_PATH/docs/* $TARGET_PATH

  # Adjustments
  rm -f $TARGET_PATH/README.md # we don't want to preserve this one
  set_nav_order $TARGET_PATH/index.md $ORDER
}

while getopts ":d" option; do
   case $option in
      d) # dev (local) mode, assumes that we are siblings of other source packages
         SOURCE=".."
         ;;
   esac
done

git submodule update --init

copy_docs cumulus-library-core library 1
