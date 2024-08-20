---
title: Authoring studies in Cumulus
_parent: Overview
nav_order: 1
# audience: clinical researcher, unfamiliar with the project
# type: Explanation
---
# Introduction to studies in Cumulus

Cumulus studies aim to help enable address the following kinds of research
questions:

- How can I compute a phenotype from the data in my EHR? And how would I apply
that phenotype so I could conduct a clinical study?
- How do I sample a cohort from my institution's patient population?
- How do I make my work repeatable at another institution?

By providing a set of tools to help answer these questions, we aim to
accelerate the time from clinical question to actionable answer based on data
you already have. After the initial configuration to get the Cumulus framework
up and running, you can reuse much of that work for future research questions.

We've published several papers using Cumulus, to give you the idea of the work
the project enables. You can see the full list on the 
[study list](https://docs.smarthealthit.org/cumulus/library/study-list.html)
\- each study contains a link to the associated paper.

## What you'll need

- You'll need the
[Cumulus ETL](https://docs.smarthealthit.org/cumulus/etl/)
set up to get data from your EHR if you haven't already. This usually requires
an IT project to initially configure. This handles extracting and de-identifying
the patient data.
- You'll need the
[Cumulus Library](https://docs.smarthealthit.org/cumulus/library/)
to help you analyze the data.
- You may need someone from your EHR support team to help you define a
patient cohort in your EHR system.
- You may need a data analyst who knows SQL and Python.

## Designing a study

Here's a workflow that most Cumulus studies will follow some version of.

### Define the question you're asking

Here are some examples of questions that have used Cumulus as a tool for analysis:

- [Can I detect patient symptoms from physician notes?](https://github.com/smart-on-fhir/cumulus-library-covid)
- [What was the effect of the Covid-19 pandemic on suicidality rates?](https://github.com/smart-on-fhir/cumulus-library-suicidality-los)
- [How much does my EHR comply with the requirements of the US Core Profile?](https://github.com/smart-on-fhir/cumulus-library-data-metrics/)

Generally, a good question for cumulus has one or more of the following qualities:

- Leverages the kind of data that would be found inside an EHR (i.e. encounter/patient
focused summary data)
- Targets a population larger than the footprint of a particular institution, requiring
data sharing between hospitals
- Uses clinical notes for identification of features, which requires NLP/LLM

Additionally, after initial setup, Cumulus offers good workflow repeatability for
studies. With a large extract from an EHR, you can ask questions, and get answers,
very quickly, so it becomes a more convenient source to use in general biostatistics
analysis.


### Create a patient cohort

There are two strategies for creating patient cohorts:

#### Inside Cumulus

Cumulus is designed to have a large export of hospital EHR data in it. If you
have such an extract, you'll need to filter relevant patients from the rest of
the population. Common strategies include:
- Encounters within a specific date range
- Encounters where a patient exhibited a symptom/set of symptoms
- Patients of a certain age range at time of encounter

You (or your data analyst) can create a table of relevant patients/encounters
implementing these constraints, and use this as a basis for additional downstream
queries.

#### Inside your EHR

If you are only loading targeted data into Cumulus, you can use the cohort creation
tools provided by your EHR to accomplish the same goals. You'll need to work with someone
on your EHR team to get the cohort specified and available for export.

### Consider if you need NLP/LLM analysis

Using natural language tools requires either leveraging an existing, or adding a new,
step to the Cumulus ETL pipeline. These are a little more complex, and will require some
more support from IT staff. The general approach is as follows:

#### Sample patients and perform chart review

For validation, you'll need some source of ground truth to evaluate your natural
language approach. We recommend getting an instance of 
[Label Studio](https://labelstud.io/)
deployed inside an environment suitable for PHI. You can then ID a human manageable
number of patients (i.e. in the low hundreds). If you want, you can leverage
[propensity score matching](https://docs.smarthealthit.org/cumulus/library/statistics/propensity-score-matching.html)
to generate a set of positive/negative groups around a specific feature.
Once you've got a cohort, you can use
[Cumulus ETL](https://docs.smarthealthit.org/cumulus/etl/chart-review.html)
to load notes into this environment. 

#### Decide on approach with your chart review data

You can use Label Studio to annotate the appropriate features (i.e. symptoms, 
clinical procedures, etc) in your patient cohort. With this labeled data, you
can try NLP/LLM approaches, and use this dataset for validating how they
performed. The exact form of this will depend on the particular technology used - 
for an example, see the 
[Infectious Respiratory Disease Symptoms](https://github.com/smart-on-fhir/infectious-symptoms-llm-study)
project for an approach based on prompt iteration for LLMs.

#### Configure ETL to use your approach and rerun extract

Once you've got a LLM approach, your IT staff will need to 
[add it to the ETL](https://docs.smarthealthit.org/cumulus/etl/nlp.html).
This is fairly simple for tasks leveraging a previously configured LLM.
After this, you simply rerun the ETL, and a table containing the outputs
of the LLM should be available for use in your study.

### Build your study

A 
[Cumulus study](https://docs.smarthealthit.org/cumulus/library/creating-studies.html)
is a collection of intersections between different 
[FHIR resources](https://docs.smarthealthit.org/cumulus/resources.html)
based on some properties among those resources. They can be expressed
via sentences, like:
- Give me every patient from the cohort with an encounter betweeen two dates
- Give me every patient that had a medication request for a specific medication
- Give me every patient that had a symptom that was IDed by my LLM module

You, or your data analyst, can convert statements like these into SQL queries.
The result of these can then be counted and binned.

### Analyzing results

Cumulus counts are outputted as power sets - you can analyze these in your
statistical package of choice, or you can upload them to the
dashboard
to use our chart building tools to review your data. If you are collaborating
with other institutions, you can upload your data to the
[aggregator](https://docs.smarthealthit.org/cumulus/aggregator/integration.html)
to automatically merge together data from the study participants.
