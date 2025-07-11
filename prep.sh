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

rewind_submodule_to_last_tag()
{
  REPO=sources/$1
  LATEST_TAG=$(git -C $REPO describe --abbrev=0 --tags)
  git -C $REPO checkout "$LATEST_TAG"
}

while getopts ":d" option; do
   case $option in
      d) # dev (local) mode, assumes that we are siblings of other source packages
         SOURCE=".."
         ;;
   esac
done

git submodule update --init --remote

# Some projects do proper releases, and for those we should only
# reference the latest tagged release. Other projects (like the
# aggregator) don't do normal releases and so can just pull from main.
if [ "$SOURCE" = "$DEFAULT_SOURCE" ]; then
  rewind_submodule_to_last_tag cumulus-etl
  rewind_submodule_to_last_tag cumulus-library
  rewind_submodule_to_last_tag chart-review
  rewind_submodule_to_last_tag smart-fetch
fi

# Only use nav_order 10-20 for submodules
copy_docs cumulus-etl etl 10
copy_docs cumulus-library library 11
copy_docs cumulus-aggregator aggregator 12
copy_docs chart-review chart-review 13
copy_docs smart-fetch fetch 14
