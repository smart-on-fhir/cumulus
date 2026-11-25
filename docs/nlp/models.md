---
title: Supported Models
parent: NLP
nav_order: 2
# audience: engineer familiar with the project
# type: reference
---

# Supported NLP Models

There are multiple ways to access the NLP models a study will need.

For example, the GPT-OSS 120b model can be used through Azure, Bedrock,
or a local on-prem copy of the model.

Below, you can see a support matrix of the models and providers that Cumulus Library supports.
Individual study support might be more limited, depending on the study design.
But these are all the models that a study _ought_ to make use of:

| Model             | `--nlp-model`   | Azure | Bedrock | Local |
|-------------------|-----------------|-------|---------|-------|
| Claude Sonnet 4.5 | `claude-sonnet45` | ❌   | ✅       | ❌     |
| Claude Sonnet 4.6 | `claude-sonnet46` | ❌   | ✅       | ❌     |
| Claude Opus 4.8   | `claude-opus48` | ❌     | ✅       | ❌     |
| GPT 5             | `gpt5`          | ✅     | ❌       | ❌     |
| GPT 5.4           | `gpt54`         | ✅     | ❌       | ❌     |
| GPT 5.4 mini      | `gpt54-mini`    | ✅     | ❌       | ❌     |
| GPT 5.4 nano      | `gpt54-nano`    | ✅     | ❌       | ❌     |
| GPT OSS 120b      | `gpt-oss-120b`  | ✅     | ✅       | ✅     |
| Llama4 Scout      | `llama4-scout`  | ✅     | ✅       | ✅ (experimental) |

Below are models that are technically supported but are on their way towards official deprecation:

| Model             | `--nlp-model`   | Azure | Bedrock | Local |
|-------------------|-----------------|-------|---------|-------|
| GPT 3.5           | `gpt35`         | ✅     | ❌       | ❌     |
| GPT 4             | `gpt4`          | ✅     | ❌       | ❌     |
| GPT 4o            | `gpt4o`         | ✅     | ❌       | ❌     |

For which models support cheaper batch processing,
see the [NLP workflow documentation](https://docs.smarthealthit.org/cumulus/library/workflows/nlp.html#supported-models).

## Choosing a Model and Provider

Pass `--nlp-model` and `--nlp-provider` when building a study with Cumulus Library:

```sh
cumulus-library build --target my_study \
  --nlp-model gpt-oss-120b --nlp-provider bedrock \
  ...
```

### Using Azure

- Pass `--nlp-provider=azure`
- Set `AZURE_OPENAI_API_KEY` and `AZURE_OPENAI_ENDPOINT` environment variables
- If your Azure deployment isn't named after the model, pass `--azure-deployment=NAME`

### Using Bedrock

- Pass `--nlp-provider=bedrock`
- Set the appropriate AWS environment variables, like `AWS_PROFILE` or `AWS_ACCESS_KEY_ID` etc.
  (or pass `--profile`)

### Using a Local Model

- Pass `--nlp-provider=local` (this is the default)
- Start the model with Docker, using the compose file shipped with Cumulus Library.
  See [Using a Local LLM](https://docs.smarthealthit.org/cumulus/library/workflows/nlp.html#using-a-local-llm)
  for details and hardware requirements.
