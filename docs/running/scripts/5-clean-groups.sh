#!/bin/sh
#SBATCH --partition=bch-compute
#SBATCH --output=logs/%x.log
#SBATCH --nodes=1
#SBATCH --mem=1G
#SBATCH --time=1-00

set -e

if [ ! -d ../groups ]; then
  echo "Run this from the refresh folder"
  exit 1
fi
cd ../data

force="$1"

groups=$(ls -d MRN-*)
for group in $groups; do
  old_dirs=$(ls -F $group | grep '/$' | head -n-1)
  for old_dir in $old_dirs; do
    if [ "$force" = "-f" ]; then
      rm -rf $group/$old_dir
    else
      echo "Would delete: $group/$old_dir"
    fi
  done
done

if [ "$force" != "-f" ]; then
  echo "To really delete them, pass -f"
fi
