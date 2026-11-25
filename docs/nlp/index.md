---
title: NLP
nav_order: 3
has_children: true
# audience: non-programmers, conversational tone, selling a bit
# type: explanation
---

# How Does Cumulus Use NLP?

One of the big features of Cumulus is the ability to easily unlock findings from your
clinical notes with the power of natural language processing (NLP).

The general idea is that Cumulus can run your clinical notes through a large language model (LLM),
extract findings of interest,
and record those findings alongside the coded FHIR data.

This way you can often surface clinical findings that simply aren't recorded in the structured
FHIR data.

## NLP Is Always Tied to a Specific Clinical Purpose

The first thing to understand is that Cumulus always
runs NLP in the context of a specific clinical purpose,
which we'll call a "study."

Each study's design will have its own questions to ask of the notes,
so each study defines its own prompts and its own expected answers.

{: .note }
Example: a infectious disease symptoms study might ask an LLM
"Does the patient in this clinical note have a fever?",
while a chronic disease-specific study might ask "when was the disease first diagnosed".

### But With Re-Usable Workflows

While the clinical "business logic" of what NLP queries to make is inevitably study-specific,
the code structure of Cumulus is generic.
That's what makes it easy to support multiple different NLP strategies.
Studies describe their NLP needs in a small configuration file called an
[NLP workflow](https://docs.smarthealthit.org/cumulus/library/workflows/nlp.html),
and [Cumulus Library](https://docs.smarthealthit.org/cumulus/library/) does the rest.

Here's a basic outline of how Cumulus runs NLP for a study:
1. Select which clinical notes are worth looking at
   (for example, notes for patients in the study cohort, or notes mentioning a keyword)
2. Send each selected note to an LLM, along with the study's prompt and question schema
3. Record the structured, extracted answers in a database table
4. Use SQL to examine the extracted data along with structured FHIR data to determine study results

Because Cumulus Library has a growing internal library of NLP support code
(things like automatically caching results, supporting different LLM providers like Azure and
Bedrock, enforcing JSON schemas for responses, and batching requests to save money),
the study-specific code can focus on the clinical logic.

#### Example Workflow

A study's NLP workflow is a TOML file that looks something like this:

```toml
config_type = "nlp"

[tables.fever]
version = 0
system_prompt = """
You are a clinical chart reviewer.
Determine whether the patient in this clinical note has a fever.

Pydantic Schema:
%JSON-SCHEMA%
"""
response_schema = "fever.json"
select_by_word = ["fever", "febrile", "pyrexia"]
```

The `fever.json` file it points at is the response schema:
a description of exactly what shape of answer the LLM must give.
Studies usually write it as a small [Pydantic](https://docs.pydantic.dev/) model
and generate the JSON from that:

```python
from pydantic import BaseModel, Field

class FeverMention(BaseModel):
    has_fever: bool = Field(description="Whether the note says the patient has a fever")
    spans: list[str] = Field(description="Exact quotes from the note that support the answer")
```

That's it.
When the study is built, Cumulus Library finds every note that mentions a fever,
asks the LLM about it, and writes the answers to a table like `my_study__nlp_fever_gpt_oss_120b`.

## Asking Good Questions

The machinery is the easy part.
The real work of an NLP study is deciding what to ask,
and the schema is where that thinking gets pinned down.
It's worth getting right before you run anything,
because every answer the LLM gives (and every chart review that checks those answers)
will take the schema's shape.

A few rules of thumb:
- **Ask what a single note can answer.**
  The LLM sees one note at a time.
  "Did this note document a fever?" works;
  "Did this patient ever have a fever?" is a question for your study's SQL,
  which can combine answers across all of a patient's notes.
- **Prefer closed answers.**
  Yes/no fields, dates and fixed lists of choices are easier for the model to get right,
  easier for SQL to count, and easier for a human reviewer to check than free text.
  When you offer a list of choices, include a way out like "none of the above" or "not mentioned,"
  so the model isn't pushed into picking a wrong answer.
- **Separate "not mentioned" from "no."**
  A note that never discusses fever is different from one that says "afebrile."
  Your schema should let the model say which.
- **Ask for evidence.**
  Asking the model to quote the text behind its answer (the `spans` field above)
  makes its answers much easier to check during chart review.
- **Use the field descriptions.**
  The schema is sent to the model, so each field's description is part of your prompt.
  Say exactly what counts, like whether a family history of fever counts as fever.
- **Expect to iterate.**
  Your first questions will be wrong in ways that only show up once you compare against
  human chart review.
  Each time you change a question or schema in a meaningful way, bump the workflow's `version`
  so old cached answers aren't reused.

For real-world examples, see the response schemas of the
[kidney transplant study](https://github.com/smart-on-fhir/cumulus-library-kidney-transplant/tree/main/cumulus_library_kidney_transplant/llm/schemas).
Cumulus Library also provides
[shared Pydantic building blocks](https://docs.smarthealthit.org/cumulus/library/workflows/nlp-tables.html#writing-response-schemas-that-work-with-these-builders)
for common needs like supporting quotes and partial dates.

## Which LLMs?

Some LLMs are freely-distributable like OpenAI's [GPT-OSS](https://openai.com/index/introducing-gpt-oss/),
and thus can be run locally.
Others are cloud-based proprietary LLMs like Anthropic's Claude or OpenAI's GPT models,
which your institution may have a HIPAA Business Associate Agreement (BAA) with.

Cumulus can handle either type.
See [Supported Models](models.md) for the full list.

### Local LLMs

With a local LLM,
your notes never leave your network and the only cost is GPU time.

Which is great!
But they can be complicated to set up.
That's where Cumulus can help by shipping a turnkey Docker configuration for these LLMs.
For example, on a machine with enough GPU memory, starting GPT-OSS is a single command
(run from a checkout of [Cumulus Library](https://github.com/smart-on-fhir/cumulus-library)):

```shell
docker compose -f docs/compose-nlp.yaml up gpt-oss-120b --wait
```

{: .note }
The local models are served with the standard
[vLLM inference interface](https://github.com/vllm-project/vllm),
so integrating new local LLMs is a lightweight process.

### Cloud LLMs

Your institution may have a BAA to share protected health information (PHI) with a cloud LLM,
through a provider like Azure or AWS Bedrock.

Talking to a cloud LLM is very similar to a local LLM.
Instead of making an internal network call to a Docker container,
Cumulus Library makes an external network call to the cloud.
99% of the Cumulus workflow is the same.

One additional challenge with cloud LLMs is reproducibility,
but recording metadata like the model name, the time, and any vendor fingerprint
along with the results can at least help explain changes over time.

## Technical Workflow

How does it all really work though?
Be warned that this next section will get a little technical.

### Running a Study's NLP

NLP runs as part of building a study with Cumulus Library.
You point it at your clinical notes, tell it which model to use, and build:

```sh
cumulus-library build \
  --target my_study \
  --note-dir s3://my-bucket/notes/ \
  --etl-phi-dir s3://my-phi-bucket/ \
  --nlp-model gpt-oss-120b \
  --nlp-provider bedrock
```

1. Cumulus Library reads the DocumentReference and DiagnosticReport FHIR resources
   in your note folder.
2. It selects the notes the study's workflow asked for.
3. It feeds those notes to the LLM, along with the study's prompt.
4. It writes the results (but not the note!) out to your Athena database,
   right alongside the rest of your Cumulus data.
5. The rest of the study's SQL then uses those results.

See the [NLP workflow documentation](https://docs.smarthealthit.org/cumulus/library/workflows/nlp.html)
for all the options, like running faster with concurrency or cheaper with batching.

### Where Does the Note/PHI Live?

After Cumulus Library runs NLP on a note, it no longer needs the note.

The note is never pushed to Athena (only the NLP results are, using anonymized IDs).

The LLM's responses are cached, so that we only need to pay to process each note once.
But that cache lives in the same PHI folder you already use with Cumulus ETL.
That is a separate location from the Athena databases and can be entirely local to your machine.

### NLP Results

The NLP responses are written to an Athena table and can be queried using SQL,
usually by study-specific SQL in the same study.

For the fever example above, a row in the results table might look like
(in JSON form):
```json
{
  "note_ref": "DocumentReference/<anonymized ID>",
  "encounter_ref": "Encounter/<anonymized ID>",
  "subject_ref": "Patient/<anonymized ID>",
  "generated_on": "2026-01-20T20:00:00+00:00",
  "task_version": 0,
  "model": "gpt-oss-120b",
  "result": {
    "has_fever": true,
    "spans": ["pt presents with fever of 101.3"]
  }
}
```

As the study SQL processes those results
and cross-references the patients & encounters,
it generates counts of patients with fevers.
Those counts are then sent to the Cumulus Dashboard and
can then finally be displayed as digestible charts.

And that's the lifecycle of a clinical note!
It starts inside your EHR,
flows through the ETL and into an LLM,
its findings end up in Athena,
and counts of those findings get sent to & displayed in the Dashboard.

Or a study might then prepare some labels for human chart review,
to validate the findings.
To read a more comprehensive end-to-end example of NLP, see [our example workflow](./example.md).
