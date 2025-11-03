---
title: NLP
nav_order: 2
has_children: true
# audience: non-programmers, conversational tone, selling a bit
# type: explanation
---

# How Does Cumulus Use NLP?

One of the big features of Cumulus is the ability to easily unlock findings from your
clinical notes with the power of natural language processing (NLP).

The general idea is that Cumulus can run NLP over your clinical notes,
extract findings of interest,
and record those findings alongside the coded FHIR data.

This way you can often surface clinical findings that simply aren't recorded in the structured
FHIR data.

## NLP Is Always Tied to a Specific Clinical Purpose

The first thing to understand is that Cumulus always
runs NLP in the context of a specific clinical purpose,
which we'll call a "study."

Each study's design will have its own needs and its own NLP strategy,
so Cumulus supports multiple approaches.

{: .note }
Example: The `covid_symptom` study used cTAKES and a negation transformer working together to tag
infectious disease symptoms in clinical notes.
But another study might use the GPT-OSS large language model,
with a prompt like "Does this patient have a nosebleed?"

### But With Re-Usable Code

While the clinical "business logic" of how to drive NLP is inevitably study-specific,
the code structure of Cumulus is generic.
That's what makes it easy to support multiple different NLP strategies.

We'll go into more depth about what an NLP task does under the covers [below](#technical-workflow).
But for now, here's a basic outline of how Cumulus runs an NLP study task:
1. Prepare the clinical notes
2. Hand those notes to a bit of study-specific Python code (which probably talks to an LLM)
3. Record the structured, extracted answers in an AWS Athena database
4. Use SQL to examine the extracted data along with structured FHIR data to determine study results

Because Cumulus has a growing internal library of NLP support code
(things like automatically caching results, supporting different LLM providers like Azure and
Bedrock, enforcing JSON schemas for responses),
the study-specific code can focus on the clinical logic.

#### Example Code
In pseudocode, here's what a task that talks to an LLM like GPT-OSS might look like:

```python
for clinical_note in etl.read_notes():
    prompt = "Does the patient in this clinical note have a nosebleed?"
    schema = {"has_nosebleed": "boolean"}
    yield etl.ask_gpt_oss(prompt, schema, clinical_note)
```

Those calls to `etl.*` are calls to the internal NLP support code that the task does not have to
re-invent.

And with that relatively low level of complexity
(though developing the best prompt can be its own challenge and is out of scope for this document),
you've got a study task that you can run over all your institution's clinical notes. 

## Available NLP Strategies

### Large Language Models (LLMs)

Cumulus makes it easy to pass clinical notes to an LLM,
which are often difficult to set up yourself.

Some LLMs are freely-distributable like Meta's [Llama](https://www.llama.com/),
and thus can be run locally.
While others are cloud-based proprietary LLMs like OpenAI's [ChatGPT](https://openai.com/chatgpt),
which your institution may have a HIPAA Business Associate Agreement (BAA) with.

Cumulus can handle either type.

#### Local LLMs

With a local LLM,
your notes never leave your network and the only cost is GPU time.

Which is great!
But they can be complicated to set up.
That's where Cumulus can help by shipping turnkey configurations for these LLMs.

See full details [below](#docker-integration),
but the basic idea is that Cumulus will download the LLM for you,
configure it for study needs, and launch it.
We'll also be able to offer recommendations on what sort of hardware you'll need.

{: .note }
Cumulus ETL uses the standard
[vLLM inference interface](https://github.com/vllm-project/vllm)
as an abstraction layer, so integrating new local LLMs is a lightweight process.

#### Cloud LLMs

Your institution may have a BAA to share protected health information (PHI) with a cloud LLM.

Talking to a cloud LLM is very similar to a local LLM.
Instead of making an internal network call to a Docker container,
Cumulus ETL makes an external network call to the cloud.

The exact API is different, but the concept is the same.
And importantly, 99% of the Cumulus workflow is the same.
It would just swap out the actual call to the LLM.

One additional challenge with cloud LLMs is reproducibility,
but recording metadata like the current time and vendor version in the database
along with the results can at least help explain changes over time.

### Others

Cumulus has supported other approaches like cTAKES.
Different transformers or services could be integrated, as needed.
If a new study required a new service, Cumulus can add support for it,
and then _any_ study would be able to use it.

## Technical Workflow

How does it all really work though?
Be warned that this next section will get a little technical.

### Docker Integration

Services like GPT-OSS and cTAKES can be launched with a single command,
because we ship Docker definitions for them.

All _you_ have to bring to the table is your own GPU hardware.

#### Example

As an example, let's say you want to run the GPT-OSS model, to use in a study that supports it.
Just run the command below
(on a machine powerful enough to handle it - per the study's documentation):
```shell
docker compose up --wait gpt-oss-120b
```

(This is a Docker Compose command, using the Cumulus ETL compose file.
More specific instructions on how to set up services for a study will be provided by each study's
documentation.)

That command works because Cumulus ETL ships a Docker Compose file with stanzas like:
```yaml
ctakes-covid:
  image: smartonfhir/ctakes-covid:1.1.1
  environment:
    - ctakes_umlsuser=umls_api_key
    - ctakes_umlspw=${UMLS_API_KEY:-}
  networks:
    - cumulus-etl
  profiles:
    - covid-symptom-gpu
```

Docker will download the referenced image and launch it with the specified configuration.

### Study Task

Once you've prepared the services the study will need with Docker Compose,
you can actually run Cumulus ETL on your clinical notes.

1. Run the specific NLP study task you are interested in.
   For example, `docker compose run cumulus-etl-gpu nlp --task covid_symptom__nlp_results …`
2. Cumulus ETL will read your DocumentReference FHIR resources.
3. It will download the clinical notes mentioned by those DocumentReferences.
4. It will feed those notes to an NLP service (in this case, to cTAKES).
5. It will write the results (but not the note!) out to an Athena database,
   just like it does with basic FHIR resources.
   In this example, the results might be a list of infectious disease symptoms that cTAKES
   found in the note.

#### Where Does the Note/PHI Live?

After Cumulus ETL downloads the clinical note and runs NLP on it,
it no longer needs the note.

The note is never pushed to Athena (only the NLP results are).

Some aspects of the note might be cached.
For example cTAKES results are cached, so that we only need to run cTAKES once per note.
But that will be in a special PHI-capable folder that you provide Cumulus ETL with.
That is separate location from the Athena databases and can be entirely local to your machine.

### NLP Results

The NLP responses are written to an Athena database and can be queried using SQL.
Usually by study-specific SQL integrated into the
[Cumulus Library](https://docs.smarthealthit.org/cumulus/library/).

[In the `covid_symptom` example we've been using,
the Athena database row for a `fever` cTAKES match in a clinical note would look something like
(in JSON form):
```json
{
  "id": "<anonymized ID>",
  "docref_id": "<anonymized ID>",
  "encounter_id": "<anonymized ID>",
  "subject_id": "<anonymized ID>",
  "generated_on": "2020-01-20T20:00:00+00:00",
  "task_version": 3,
  "match": {
    "begin": 36,
    "end": 41,
    "text": "fever",
    "polarity": 0,
    "conceptAttributes": [
      {"code": "386661006", "cui": "C0015967", "codingScheme": "SNOMEDCT_US", "tui": "T184"},
      {"code": "50177009", "cui": "C0015967", "codingScheme": "SNOMEDCT_US", "tui": "T184"}
    ],
    "type": "SignSymptomMention"
  }
}
```

As the Cumulus Library SQL processes all the detected symptoms
and cross-references the patients & encounters,
it generates counts of patients with fever, headaches, etc.
Those counts are then sent to the Cumulus Dashboard and
can then finally be displayed as digestible charts.

And that's the lifecycle of a clinical note!
It starts inside your EHR,
flows through the ETL & related NLP services,
its symptoms end up in Athena,
and counts of those symptoms get sent to & displayed in the Dashboard.

Or a study might then prepare some labels for human chart review,
to validate the findings.
To read a more comprehensive end-to-end example of NLP, see [our example workflow](./example.md).
