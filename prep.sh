#!/bin/sh
set -e

ROOT=`pwd`
DOCS=$ROOT/docs

copy_docs()
{
  REPO=$1
  TARGET=$2
  REPO_PATH=sources/$REPO
  TARGET_PATH=$DOCS/$TARGET

  echo "Copying $REPO to $TARGET"
  rm -rf $TARGET_PATH
  mkdir -p $TARGET_PATH
  cp -r $REPO_PATH/docs/* $TARGET_PATH
  rm -f $TARGET_PATH/README.md # we don't want to preserve this one
}

git submodule update --init

copy_docs cumulus-library-core library
