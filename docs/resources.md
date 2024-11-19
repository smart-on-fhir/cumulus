---
title: Supported Resources
_parent: Overview
nav_order: 3
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

| Resource           | ETL           | `core` |
|--------------------|---------------|--------|
| AllergyIntolerance | ✅             | ✅      |
| Condition          | ✅             | ✅      |
| Device             | ✅             | ❌      |
| DiagnosticReport   | ✅             | ❌      |
| DocumentReference  | ✅             | ✅      |
| Encounter          | ✅             | ✅      |
| Immunization       | ✅             | ❌      |
| Medication         | ✅<sup>1</sup> | ✅      |
| MedicationRequest  | ✅             | ✅      |
| Observation        | ✅             | ✅      |
| Patient            | ✅             | ✅      |
| Procedure          | ✅             | ❌      |
| ServiceRequest     | ✅             | ❌      |

1. Medications are not usually bulk-exportable.
Instead, as the ETL processes MedicationRequest resources,
it downloads any linked Medication resources as well.
