#!/bin/sh

GROUP=$1
if [ -z "$GROUP" ]; then
  echo "Provide a group (like MRN-123)"
  exit 1
fi

NICK=$2
if [ -z "$NICK" ]; then
  echo "Provide a nickname (like 2025-12)"
  exit 1
fi

if ! echo "$GROUP" | grep -q "^MRN-"; then
  echo "Group $GROUP doesn't look like a group."
  echo "This script requires GROUP NICK in that order"
  exit 1
fi

if grep -qs "^$GROUP,$NICK$" "$HOME/done.txt"; then
  echo "Skipping $GROUP, already done."
  exit 0
fi

TARGET=$(aws s3 ls "s3://cumulus-etl-phi-123456789012-us-east-1/_exports/ehr-name//$GROUP/" | grep -s -o "[0-9]\+\.$NICK/")
if [ -z "$TARGET" ]; then
  echo "Could not find $NICK folder in $GROUP"
  exit 1
fi

OPT=""
# Grab last character of GROUP, to see if it's a 0, so that we
# only run optimizations every ten groups - it's faster if we do
# not constantly rebalance the parquet files, but doing so every
# now and then keeps our writes from slowing down over time.
if [ "${GROUP#??????}" != "0" ]; then
  OPT="--no-table-optimization"
fi

if time docker compose -f ~/cumulus-etl/compose.yaml \
  run --rm \
  cumulus-etl etl \
  --batch-size 100000 \
  $OPT \
  s3://cumulus-etl-phi-459510994822-us-east-1/test_patient \
  s3://cumulus-etl-output-459510994822-us-east-1/epic \
  s3://cumulus-etl-phi-459510994822-us-east-1/epic; then
  echo "$GROUP,$NICK" >> "$HOME/done.txt"
fi
