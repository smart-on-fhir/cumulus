#!/usr/bin/env -S python3.11 -u

import argparse
import asyncio
import binascii
import csv
import gzip
import hmac
import os
import subprocess

import cumulus_fhir_support as cfs

FHIR_URL= "https://epicproxy-np.et1351.epichosted.com/APIProxyPJX/api/FHIR/R4/"
AUTH_URL= "https://epicproxy-np.et1351.epichosted.com/APIProxyPJX/oauth2/token"
CLIENT_ID= "your_client_id"
PATIENT_SYSTEM = "urn:oid:1.2.840.114350.1.13.713.2.7.5.737384.14"
SALT="your_salt"
JWKS_KEY = {"your": "jwkskey"}

parser = argparse.ArgumentParser()
parser.add_argument("group")
args = parser.parse_args()

done_mrns = set()
new_file = False
try:
  with gzip.open("../patients.csv.gz", "rt", encoding="utf8") as f:
    reader = csv.DictReader(f)
    for row in reader:
      done_mrns.add((row["mrn"], row["group_name"]))
except FileNotFoundError:
  new_file = True


async def main():
  with (
    gzip.open("../patients.csv.gz", "at", encoding="utf8") as out,
    open(f"../groups/{args.group}", encoding="utf8") as group,
  ):
    writer = csv.writer(out)
    if new_file:
      writer.writerow(["fhir_id", "mrn", "anon_id", "group_name"])

    def add_row(fhir_id, mrn):
      if (mrn, args.group) in done_mrns:
        return  # can happen if two MRNs in same group return same record
      if fhir_id:
        anon_id = hmac.new(binascii.unhexlify(SALT), digestmod="sha256", msg=fhir_id.encode("utf8")).hexdigest()
      else:
        anon_id = ""
      writer.writerow([fhir_id, mrn, anon_id, args.group])

    async with cfs.FhirClient(
      FHIR_URL
      ["Patient"],
      token_url=AUTH_URL,
      smart_client_id=CLIENT_ID,
      smart_jwks=JWKS_KEY,
    ) as client:
      for mrn in group:
        mrn = mrn.strip()
        if (mrn, args.group) in done_mrns:
          continue

        response = await client.request("GET", f"Patient?identifier={PATIENT_SYSTEM}|{mrn}")
        bundle = response.json()

        for link in bundle.get("link", []):
          if link.get("relation") == "next":
            raise ValueError(f"found next link for {mrn}")

        for entry in bundle.get("entry", []):
          resource = entry["resource"]
          if resource["resourceType"] != "Patient":
            if resource["issue"][0]["details"]["text"] in {
              "Resource request returns no results.",
              }:
              add_row("", mrn)
              continue
            raise ValueError(f"Did not understand {mrn} resource {resource}")
          add_row(resource["id"], mrn)
          for identifier in resource.get("identifier", []):
            if identifier.get("system") == PATIENT_SYSTEM:
              value = identifier.get("value")
              if value != mrn:
                add_row(resource["id"], value)

        done_mrns.add((mrn, args.group))


asyncio.run(main())