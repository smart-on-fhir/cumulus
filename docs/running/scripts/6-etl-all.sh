#!/bin/sh

NICK=$1
if [ -z "$NICK" ]; then
  echo "Provide a nickname (like 2025-12)"
  exit 1
fi

# get all groups, in reverse order (so that we ETL the new patients first)
ALL_GROUPS=$(aws s3 ls "s3://umulus-etl-phi-123456789012-us-east-1/_exports/ehr-name/" | grep -s -o "MRN-[0-9]\+" | sort -r)

for g in $ALL_GROUPS; do
  if ! ./ec2-etl-one-group $g $NICK; then
    break
  fi
done

echo "Stopped!"
read -p "Press enter to exit" accepted
