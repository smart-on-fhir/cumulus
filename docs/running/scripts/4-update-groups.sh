#!/bin/sh
#SBATCH --partition=bch-compute,bch-compute-pe
#SBATCH --output=logs/%x.log
#SBATCH --nodes=1
#SBATCH --mem=2G
#SBATCH --time=7-00

set -e

NICK=$1
if [ -z "$NICK" ]; then
  echo "Provide a nickname (like 2025-12)"
  exit 1
fi

START=$2
if [ -z "$START" ]; then
  echo "Exporting all groups"
else
  echo "Exporting some groups, starting with $START"
fi

if [ ! -d ../groups ]; then
  echo "Run this from the refresh folder"
  exit 1
fi

ARRAY=

for group in ../groups/*; do
  if [ -n "$START" ]; then
    if [ "$(basename $group)" = "$START" ]; then
      START=
    else
      continue
    fi
  fi
  group=$(basename $group)
  if grep -qs '"complete": true' ../data/$group/*.$NICK/.metadata; then
    continue
  fi

  NUM=$(echo $group | cut -d- -f2 | bc)
  if [ -z "$ARRAY" ]; then
    ARRAY=$NUM
  else
    ARRAY=$ARRAY,$NUM
  fi
one

# Aggro mode - start a bunch of simultaneous sbatch jobs
if [ -n "$ARRAY" ]; then
  echo "Using array: $ARRAY"
  sbatch --array $ARRAY%40 -J export ./export-one-group $NICK
fi

echo "Done exporting all groups."
