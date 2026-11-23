#!/bin/bash

set -e

FILE="$1"

if [ -z "$FILE" ]; then
  echo "Provide a path to a csv of MRNs"
  exit 1
fi

if [ ! -d ../groups ]; then
  echo "Can't find groups directory - are you not running this from ./refresh?"
  exit 1
fi

if ! git -C ../groups diff --quiet; then
  echo "../groups folder already has some changes - fix that and come back"
  exit 1
fi

WORKDIR="/temp_work/$USER/add-new-groups"
mkdir -p "$WORKDIR"
rm -rf "$WORKDIR/*"

tail -n+2 "$FILE" | sort > "$WORKDIR/current.txt"
cat ../groups/MRN-* | sort > "$WORKDIR/old.txt"
comm -23 "$WORKDIR/current.txt" "$WORKDIR/old.txt" | grep -v "^$" > "$WORKDIR/new.txt"

LAST_NUM=$(ls ../groups/MRN-* | cut -d- -f2 | sort -n | tail -n1)
NEXT_NUM=$(($LAST_NUM + 1))

cd "$WORKDIR"
split -a 3 -l 10000 --numeric-suffixes=$NEXT_NUM new.txt MRN-

# If the last file is less than a thousand MRNs, just merge it.
# This is arbitrary, but designed to avoid really pointless groups
# with five or so patients in it.
LAST_NUM=$(ls MRN-* | cut -d- -f2 | sort -n | tail -n1)
LAST_COUNT=$(wc -l MRN-$LAST_NUM | cut -d' ' -f1)
if [ "$LAST_NUM" != "$NEXT_NUM" -a "$LAST_COUNT" -lt "1000" ]; then
  PREV_NUM=$(($LAST_NUM - 1))
  cat MRN-$LAST_NUM >> MRN-$PREV_NUM
  rm -f MRN-$LAST_NUM
fi

echo "New groups:"
NEW_FILES=$(ls MRN-*)
for file in $NEW_FILES; do
  COUNT=$(wc -l $file | cut -d' ' -f1)
  echo "$file: $COUNT"
Done

cd -
cd ../groups
mv "$WORKDIR"/MRN-* .
git add $NEW_FILES
git commit -a -m "MRN refresh"

echo "Done."
