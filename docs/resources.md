---
title: Supported Resources
_parent: Overview
nav_order: 4
# audience: non-programmers vaguely familiar with Cumulus
# type: explanation
---

# Supported FHIR Resources

## What's a Resource?

The [FHIR specification](https://www.hl7.org/fhir/R4/) describes many kinds of _resources_,
which are individual logical bundles of data.
For example: [Patients](https://www.hl7.org/fhir/R4/patient.html),
[Encounters](https://www.hl7.org/fhir/R4/encounter.html),
or [Devices](https://www.hl7.org/fhir/R4/device.html).

Resources are the atomic units of data that flow through the Cumulus pipeline.

You can bulk export them from your EHR.<br/>
You can feed them through Cumulus ETL.<br/>
And you can query them with Cumulus Library.

## Levels of Support

Only a subset of the FHIR resources are supported by Cumulus.
And not every resource enjoys the same level of support.

For a resource to enter the Cumulus pipeline, Cumulus ETL must support it.
Any resource that the ETL supports can be directly queried in Athena. 

But for more convenient querying,
the Cumulus Library's `core` study has additional support for some resources.
For example, the `core` study abstracts the complexities of querying medication
codes for you, because it has special knowledge of MedicationRequests and
Medications.

If a resource isn't supported by the `core` study, it can still be queried!
It just may not be as convenient,
as you'll have to handle directly querying FHIR nested layouts yourself.

Over time, more resources will be added to the `core` study.

## Support List

| Resource                     | ETL | `core` |
|------------------------------|-----|--------|
| AllergyIntolerance           | ✅   | ✅      |
| Condition                    | ✅   | ✅      |
| Device                       | ✅   | ❌      |
| DiagnosticReport             | ✅   | ✅      |
| DocumentReference            | ✅   | ✅      |
| Encounter                    | ✅   | ✅      |
| EpisodeOfCare                | ✅   | ✅      |
| Immunization                 | ✅   | ❌      |
| Location<sup>1</sup>         | ✅   | ✅      |
| Medication<sup>1</sup>       | ✅   | ✅      |
| MedicationDispense           | ✅   | ❌      |
| MedicationRequest            | ✅   | ✅      |
| Observation                  | ✅   | ✅      |
| Organization<sup>1</sup>     | ✅   | ✅      |
| Patient                      | ✅   | ✅      |
| Practitioner<sup>1</sup>     | ✅   | ✅      |
| PractitionerRole<sup>1</sup> | ✅   | ✅      |
| Procedure                    | ✅   | ✅      |
| ServiceRequest               | ✅   | ✅      |
| Specimen                     | ✅   | ✅      |

1. Not bulk-exportable, but can be downloaded using
   [SMART Fetch](https://docs.smarthealthit.org/cumulus/fetch/)

## Expected File Formats

Cumulus expects your FHIR data to be in a line-delimited JSON format, one resource per line.
Each file must hold only a single type of resource.

Here is how Cumulus will scan your input folders:
- The folder will be scanned recursively.
- Symlinks will be followed.
- Files with either `.ndjson` or `.jsonl` extensions will be examined.
- Additionally, the file can be gzip-compressed, with an extra `.gz` extension
  (so a total extension of `.ndjson.gz`).
- Resources can be spread across multiple files. e.g. you can have `Patient.1.ndjson` and
  `Patient.2.ndjson` and Patients from both will be read in.
- If the filename has a single obvious resource type in its filename (like `1.Patient.001.ndjson`),
  it will be assumed to hold that kind of resource. If there's no obvious resource type, the first
  line of the file will be read to inspect the type (which is slower, so it can help to add the
  correct types to your filenames).
