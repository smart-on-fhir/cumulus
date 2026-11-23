#!/bin/sh
#SBATCH --partition=bch-compute,bch-compute-pe
#SBATCH --output=logs/%x.log
#SBATCH --nodes=1
#SBATCH --mem=1G
#SBATCH --time=2-00

set -e

. $VENV_ROOT/bin/venv/bin/activate

if [ ! -d ../groups ]; then
  echo "You should run this from the refresh folder"
  exit 1
fi

START=$1
if [ -z "$START" ]; then
  echo "Checking all groups"

  # Reset file, because MRN <-> FHIR ID mappings can change over time
  rm -f ../patients.csv.gz
else
  echo "Checking some groups, starting with $START"
fi

for g in ../groups/*; do
  if [ -n "$START" ]; then
    if [ "$(basename $g)" = "$START" ]; then
      START=
    else
      continue
    fi
  fi
  echo "Checking group $g"
  python3.11 ./_update_patient_map.py $(basename $g)
done

echo "Done."
