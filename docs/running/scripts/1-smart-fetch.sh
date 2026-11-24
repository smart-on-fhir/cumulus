#!/bin/sh

set -e

MYDIR=$(dirname -- $(realpath "$0"))

if [ -n "$VENV_ROOT" ]; then
  . $VENV_ROOT/bin/activate
else
  . $MYDIR/venv/bin/activate
fi

smart-fetch -v "$@" -c $MYDIR/1a-config-ehr.toml
