#!/bin/sh
#SBATCH --partition=bch-compute,bch-compute-pe
#SBATCH --output=logs/x%a.log
#SBATCH --nodes=1
#SBATCH --mem=2G
#SBATCH --time=3-00

set -e

if [ -n "$SLURM_ARRAY_TASK_ID" ]; then
  GROUP="MRN-$(printf '%03d' $SLURM_ARRAY_TASK_ID)"
  NICK=$1
else
  GROUP=$1
  NICK=$2
fi

if [ -z "$GROUP" ]; then
  echo "Provide a group (like MRN-123)"
  exit 1
fi

if [ -z "$NICK" ]; then
  echo "Provide a nickname (like 2025-12)"
  exit 1
fi

if ! echo "$GROUP" | grep -q "^MRN-"; then
  echo "Group $GROUP doesn't look like a group."
  echo "This script requires GROUP NICK in that order"
  exit 1
fi

# We use a custom typeFilter to add the smartdata category

time smart-fetch-epic export \
  --verbose \
  --nickname "$NICK" \
  --id-system urn:oid:1.2.840.114350.1.13.713.2.7.5.737384.14 \
  --id-file /path/to/group/folders/$GROUP \
  --type-filter 'Observation?category=social-history,vital-signs,imaging,laboratory,survey,exam,smartdata' \
  /path/to/data/folders/$GROUP

echo "Done exporting $GROUP"
