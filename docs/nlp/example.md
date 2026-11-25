---
title: Example Workflow
parent: NLP
nav_order: 1
# audience: engineer familiar with the project
# type: tutorial
---

# An Example NLP Workflow

Let's work through an end-to-end NLP workflow, as if you were doing a real study.
But we'll use an example study shipped with Cumulus Library for testing purposes instead.

This will take us from the initial actual NLP, then to chart review,
then finally to analyzing accuracy.

You don't need to prepare your own clinical notes for this run-through.
We'll use synthetic notes shipped with Cumulus Library for this very purpose.

This example study we'll use is just a very simple age range study.
The NLP will only be tasked with extracting an age from a clinical note.

To keep things simple, we'll build everything into a local DuckDB database
instead of AWS Athena.
A real study would usually run against Athena, but the commands are nearly identical.

## Setup

You'll need:
- [Cumulus Library](https://docs.smarthealthit.org/cumulus/library/) installed
  (`pip install cumulus-library`)
- A local checkout of the [Cumulus Library repository](https://github.com/smart-on-fhir/cumulus-library),
  which holds the synthetic notes and the Docker file for local models
- [Cumulus ETL](https://docs.smarthealthit.org/cumulus/etl/) set up, for the chart review step

For the rest of this guide, we'll assume your Cumulus Library checkout is at `~/cumulus-library`
and refer to the example notes folder like so:
```sh
export NOTES=~/cumulus-library/cumulus_library/studies/example_nlp/notes
```

## The NLP Itself

### How the Study Is Defined

The `example_nlp` study has three stages:
1. `select_cohort.sql` picks ten notes to examine.
2. `nlp.workflow` sends those notes to an LLM, asking for the patient's age.
3. `calculate_ranges.sql` turns those ages into age range labels.

The middle step is an [NLP workflow](https://docs.smarthealthit.org/cumulus/library/workflows/nlp.html),
a small TOML file that holds the prompt, the expected response schema,
and which notes to select.
It's worth a quick read, since your own studies will define NLP the same way.

{: .note }
In a real study, the response schema is the first thing you'd design,
since it decides what questions the LLM answers and what your results tables look like.
This example skips that step with a deliberately simple schema:
`generate_schemas.py` defines a small Pydantic model
(was the age mentioned, the supporting quotes, and the age itself)
and writes it out as `age.json`, which the workflow points at.
See [Asking Good Questions](index.md#asking-good-questions) for advice on designing your own.

### Model Setup

You have a choice of model for this.
Real studies might require one specific model or another.
This example study expects the GPT-OSS 120b model (`gpt-oss-120b`),
which you can reach through a few different providers.

#### Azure
Set a couple variables first:
```sh
export AZURE_OPENAI_API_KEY=xxx
export AZURE_OPENAI_ENDPOINT=https://xxx.openai.azure.com/
```
And you'll pass `--nlp-provider azure` below.

#### Bedrock
Make sure your AWS credentials can be found (for example, by setting `AWS_PROFILE`).
And you'll pass `--nlp-provider bedrock` below.

#### Local (On-Prem)
For these, you'll need to start up the appropriate model on your machine:
Start up the model on a machine with at least 80GB of GPU memory,
from your Cumulus Library checkout:
```sh
cd ~/cumulus-library
docker compose -f docs/compose-nlp.yaml up gpt-oss-120b --wait
```
And you'll pass `--nlp-provider local` below.

With a cloud provider, this should cost you only a few cents to run.
We're only sending ten short notes.

### Loading the Notes

First, let's load the synthetic notes into a fresh DuckDB database and build the `core` study,
so that the example study can find them:
```sh
cumulus-library build \
  --target core \
  --db-type duckdb \
  --database /tmp/example.duckdb \
  --load-ndjson-dir $NOTES
```

### Running the NLP

Now that your model is ready, let's build the study, which will run NLP on those notes!

Change the provider as appropriate for your model.
The PHI folder is where Cumulus Library keeps a cache of NLP results.
In a real study, that would be the same PHI folder you use with Cumulus ETL.
There's no actual PHI in this example run because of the synthetic data,
so a temporary folder is fine.

```sh
cumulus-library build \
  --target example_nlp \
  --db-type duckdb \
  --database /tmp/example.duckdb \
  --note-dir $NOTES \
  --etl-phi-dir /tmp/example-phi \
  --nlp-model gpt-oss-120b \
  --nlp-provider bedrock
```

(If this were a real study, you'd point `--note-dir` at your real clinical notes.
And the study's workflow would probably select notes more carefully than "the first ten.")

### Confirm the Data

Let's peek at the NLP results using the [DuckDB CLI](https://duckdb.org/docs/installation/):
```sh
duckdb /tmp/example.duckdb "select note_ref, result.age from example_nlp__nlp_age_gpt_oss_120b"
```
You should see ten results with extracted ages.

Note the table name: `{study}__nlp_{table}_{model}`.
The model is part of the name, so results from different models never overwrite each other.

**Congratulations!**
You've now run NLP on some synthetic clinical notes and saved the results to a database.

## Post-Processing of the NLP Results

Studies will normally need to post-process the results of the NLP,
which is usually performing some sort of knowledge extraction.
A study might combine bits of NLP-extracted knowledge together or
cross-reference with some structured data to create a study finding, or label.

In this example study,
the last stage already post-processed the extracted ages into clinically-relevant age range labels,
in the `example_nlp__range_labels` table.
We'll compare those labels against a human review.

Let's save those labels to a CSV file for later:
```sh
duckdb /tmp/example.duckdb \
  "copy (select note_ref, label from example_nlp__range_labels) to 'gpt-oss.csv'"
```

## Human Chart Review

Now let's validate the NLP results with a human review.
To do this, we'll use Label Studio.

### Label Studio Setup

The Label Studio project itself has good
[install documentation](https://labelstud.io/guide/install.html).
We recommend you follow that and continue here once you have it installed.

You'll also need to prepare a Label Studio project to upload notes into.
Inside the main Label Studio dashboard, create a new project.
Give it a name and skip the data import step (we'll do that ourselves in a moment).

When it asks you to set up a labeling template,
click the "Custom Template" button on the bottom left.
Enter the following template, which lists the possible labels for our example study.
```
<View>
  <Labels name="label" toName="text">
    <Label value="infant (0-1)" background="#3584e4"/>
    <Label value="child (2-12)" background="#2190a4"/>
    <Label value="adolescent (13-18)" background="#3a944a"/>
    <Label value="young adult (19-24)" background="#c88800"/>
    <Label value="adult (25-44)" background="#ed5b00"/>
    <Label value="middle aged (45-64)" background="#e62d42"/>
    <Label value="aged (65+)" background="#d56199"/>
    <Label value="unknown" background="#6f8396"/>
  </Labels>
  <Text name="text" value="$text"/>
</View>
```

### Upload Your Notes

Now you'll want to fill in your new project with the clinical notes the NLP looked at.
Cumulus ETL's `upload-notes` command handles this.
Take a note of the project number (in the project's URL) and replace the number below,
along with the other arguments for your site.

The `--select-by-csv` argument uses the CSV we saved above to pick out just the ten notes
that went through NLP.
Since our CSV file is in the current folder, we mount it into the Docker container with `-v`.
```sh
docker compose run --rm \
  -v $NOTES:/notes \
  -v $PWD:/csv \
  -v /tmp/example-phi:/phi \
  cumulus-etl upload-notes \
  /notes \
  /phi \
  --select-by-csv /csv/gpt-oss.csv \
  --label-studio-url https://my-label-studio-host/ \
  --ls-project xx \
  --ls-token /path/to/token.txt
```

### Review the Charts

Refresh the project page in Label Studio and you should see a few notes in Label Studio.

Add your own label to each of the notes.
You do this by clicking on the label at the top that you want to add,
then highlighting a region of text.
Then click the Submit button to finalize it.

Feel free to agree or not with what you think the NLP said.
In fact, why don't you intentionally pick a wrong label a few times.
It will make the number crunching below more interesting.

Once you have annotated all the notes, you have finished your chart review!

## Calculate Agreement

After any sort of chart review activity,
you'll want to measure the agreement between your reviewers/annotators.

We've built a tool called `chart-review` that can generate some nice statistics for this.

But first, let's gather up all our chart annotations.

### Export Annotations

Let's download those Label Studio annotations you made.
In Label Studio, click Export in the project and choose the default JSON format.
Save this file as `labelstudio-export.json`, in the same folder as the `gpt-oss.csv` file
we saved earlier.

That CSV holds the NLP's answers, which Label Studio doesn't know about.
So with both files, you have everything you need.

### Create a Chart Review Config File

Chart Review doesn't need much configuration,
but you'll need to tell it where these exported NLP annotations are.

Create a `config.yaml` file alongside the exported annotations, with the following contents:
```yaml
annotators:
  gpt-oss:
    filename: gpt-oss.csv
```

### Running Chart Review

First, install the tool with `pipx install chart-review`.

Then, in the same folder as the other files, run `chart-review` without any arguments.
You should see output similar to the following
(these examples are from an earlier eight-note version of this study, so your numbers will differ):
```
~$ chart-review
╭───────────┬─────────────┬───────────╮
│ Annotator │ Chart Count │ Chart IDs │
├───────────┼─────────────┼───────────┤
│ 1         │ 8           │ 1305–1312 │
│ gpt-oss   │ 8           │ 1305–1312 │
╰───────────┴─────────────┴───────────╯
```

"Annotator 1" (or whatever number you see) is you, as your Label Studio ID.
You can give yourself a convenient name by editing `config.yaml` again to look like:
```yaml
annotators:
  me: 1
  gpt-oss:
    filename: gpt-oss.csv
```

Let's run chart-review again:
```
~$ chart-review
╭───────────┬─────────────┬───────────╮
│ Annotator │ Chart Count │ Chart IDs │
├───────────┼─────────────┼───────────┤
│ gpt-oss   │ 8           │ 1305–1312 │
│ me        │ 8           │ 1305–1312 │
╰───────────┴─────────────┴───────────╯
```

OK so that's not so impressive. That's some very basic information indeed.
Let's get some agreement information
(in this example, I disagreed with the model a fair bit, for demonstration purposes):
```
~$ chart-review accuracy me gpt-oss
Comparing 8 charts (1305–1312)
Truth: me
Annotator: gpt-oss
Macro F1: 0.25

F1     Sens  Spec   PPV   NPV    Kappa  TP  FN  TN  FP  Label              
0.333  0.5   0.786  0.25  0.917  0.2    2   2   22  6   *                  
0      0     0      0     0      0      0   1   7   0   adolescent (13-18) 
0.667  1.0   0.857  0.5   1.0    0.6    1   0   6   1   child (2-12)       
0.333  1.0   0.429  0.2   1.0    0.158  1   0   3   4   middle aged (45-64)
0      0     0      0     0      0      0   1   6   1   young adult (19-24)
```

Now we can see some F1 scores and all sorts of interesting stats.
Chart Review has other fun features.
You can explore its command line options with `--help`.

And that's it! You've gone from some source documents, through NLP, through human chart review,
and finally you calculated how well NLP agreed with you, the human.

In a real study, obviously all these steps would be more interesting than this toy example.
But the flow of data through the Cumulus pipeline would have the same shape.
