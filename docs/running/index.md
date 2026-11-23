---
title: Running Cumulus
nav_order: 2
has_children: true
# audience: Engineers configuring the application for the first time
# type: how to
---

# Running the Cumulus pipeline

This document outlines we run the Cumulus pipeline on our own data,
as a starting point for reference. This is not the only way to run the Cumulus
pipeline - by design, we try to make Cumulus flexible enough to run in several
contexts. We’ll try to call out places where one could reasonably make a 
different choice in how the various tools are configured.

This documentation references 
[several cloudformation templates and scripts](running-cumulus.zip).
You  should download them before reading this document, and we’ll reference them
by subfolder and name inline with the text, highlighted like so: 
`./subdir/filename.txt.`

The scripts generally assume the presence of a VENV_ROOT environment variable, which
you should point to the location you’ve installed a python virtualenv (venv) for the
purposes of running these scripts.

### Available tools

We have access to the following tools:

- We have a compute cluster which is approved for storage of PHI data. While it is also
useful for getting access to CPU/GPUs for cheap experiments, we use it as a place to
store data at rest.
- Our cloud team can provision HIIPA-compliant AWS infrastructure. We have a dedicated
AWS account for Cumulus, and use it to store the post-ETL data, as well as the
athena-based results of study runs. We can self-manage IAM permissions in that account,
and have approved our architecture with our security team.
- We can update our AWS infrastructure via CI actions from a dedicated gitops repo. We
don't expect you to do that, and that's not covered in this guide, so we'll point you
at the AWS console a little more than we would use it in house.

## AWS Configuration


We configure most of our AWS infrastructure with cloudformation templates. There’s some
bits of infrastructure that we specifically need:
- S3 buckets for input, output, and PHI data
- EC2s for running ETL
- Athena databases for library analysis

We’ll refer to some of these things later, but we’vee included the cloudformation
templates above to get the infrastructure set up for when you need it. You can opt
to do this via terraform, via AWS Infrastructure Composer, or you can create these
resources manually from the AWS console.

We have role-based access to S3, and you’ll see that referenced in the S3 configuration.
You don’t have to do this, but we think it’s wise to set up restrictions on the S3 bucket
containing PHI specifically so that only users who need to see it can.

You should set up the buckets beforehand. You can configure the EC2/Athena DBs later,
when we get to the ETL and study building sections, respectively.

For configuring buckets, first, we set up a KMS key for cumulus. `./aws/1-kms.yaml`
 creates a key that will be used to encrypt the buckets we’ll create later.

Next, we create some roles, which we’ll grant permission to use to access the buckets.
`./aws/2-iam.yaml` creates a key that will be used to encrypt the buckets we’ll create
later. These are mostly to service EC2 runners, but we’ll need the role to exist to
create the buckets, so we’ll create this now.

Then we set up the buckets, referencing the exported KMS key, in `./aws/3-s3.yaml`.
This template asks for a role name. In our case, we have some roles in AWS that have
access to the PHI bucket, and some that don’t. If you don’t need or don’t know what
to set this to, the name of the role you used to log into the AWS console (available
in the upper right; trim off anything related to your specific email if present) is
the correct role to use. You can change this later in the IAM console if you need to.
Otherwise, you can leave the default values.

This template will create three buckets:
- `Cumulus-etl-output-[account]-region`, for storing the output of cumulus-etl
- `Cumulus-etl-phi-[account]-region`, for storing the hash key for mapping from real
ID to anonymous id
- `Cumulus-athena-[account]-region`, for storing data related to AWS queries.

For the remaining templates, we use Service Catalog to create provisionable resources.
You can do this in the Administration -> Product List section of the Service catalog
console. You don’t have to do this; you could instead create resources with the
templates directly as you need them. If that’s what you want to, you can skip this
step; you can also skip the `./aws/4–optional-ec2.yaml`file if you want to run Cumulus
ETL in a different environment. If you do use the EC2 template, you’ll need to change
the subnet/security ARNs to match your VPC’s configuration.

## Smart Fetch
Inside our local compute cluster, we have a fileshare in which we store data and
tools. We have a bin directory inside that folder, in which we keep some shell scripts
related to all our transformation tools, with a python virtual environment with all the
dependencies installed. The folder containing these scripts is added to our path
variable so that these commands are generally available.

Where you see `$NICK` or nickname referenced in the scripts, that usually refers to the
datasource - so ‘epic’ and ‘cerner’ are good values for this param.

In this directory, we have a shell script, `./scripts/1-smart-fetch.sh`, which we use to
initiate the venv and load the configuration file. The config file it references drives 
mart-fetch for a given data source, at `./scripts/1a-config-ehr.toml`. We put common
command line arguments we need in the config file, so we can just run the command
without any additional input. 

The fhir/token URLs may be different for a different epic installation, and obviously
will be different for other servers. 

Your smart client ID will be the one that is provided from registering a new app with
[vendor services](https://vendorservices.epic.com/)
. In doing this, you’ll also need to specify which services you wish to
configure. You should select all the Bulk Data services, and then each R4 service for
our 
[supported FHIR resources](resources.md)
. Your Epic team may need to configure additional items for data to flow.

The steps for configuring a jwks keypair are the same as for connecting to the EPIC
sandbox, which we outline on the 
[EHR Good Neighbor site](https://good-neighbor.smarthealthit.org/sandboxes/#epic)
. We also have notes there for the Cerner sandbox, which would be about the same
as connecting to a Cerner instance.

Our slurm tasks will handle invoking this smart fetch command on the relevant data.

## Managing cohorts

This section contains a lot of bash scripts with BCH-specific folders/configurations
in them; they’re not as productionized as our published software. Take them with a
grain of salt, and expect to need to modify them to work in your infrastructure,
or use them as inspiration for your own processes.

We retrieve MRNs from a Snowflake instance by running a query selecting any MRNS
where there is an admit date on or after January 1, 2016. We then want to split those
into smaller groups, so that we can run those jobs in parallel. 

Our data is structured in the following manner in the folder we keep MRN data in:

- /data <- the extracted FHIR data
- /groups <- the bins of MRNs
- /refresh <- scripts we use for refreshing the data
- patients.csv.gz <- a mapping of patient IDs to groups and anon-ids

In /refresh, we have the following script, `./scripts/2-groups.sh`, which given a
CSV of MRNs produces the MRN bin for ETL. You’ll need to get an MRN list from a
system of record - that could be your EHR, or a standalone database (in our case,
we have a replica in snowflake). You may also want to change the path of the `WORKDIR`
variable in this script to an appropriate location for storing data for a large job.
Assuming you mimic the above directory structure, putting the contents of the scripts
subfolder in the zip archive into refresh, you’d run this command as follows:

`2-groups.sh /path/to/mrns.csv`

After executing, the /groups folder contains files with lists of MRNs.

The next step is strongly recommended: we find it useful to maintain a mapping of MRNs
to the anonymized athena IDs in case we ever need to link up external data, so we have
another script in /refresh, `./scripts/3-patient-map.sh`, (which invokes 
`./scripts/3a-update-patient-map.py`), which generates the gzipped csv based on the
new MRNs. You can run this as is with no special args.

This can take a long time - we allocate a day for this. We upload this artifact to S3
for our own convenience, which is completely optional.

In parallel, with our cohort bins, we have a pair of SLURM-based scripts that we use
to queue up smart fetch runs. `./scripts/4-update-groups.sh` , which queues up single
jobs via `/scripts/4a-update-group.sh script`. 

You will want to modify 4a-update-group in the following ways:
- in the smart-fetch section, provide the absolute path to your groups directory in
the two places it is is referenced
- change the id-system param to match the appropriate identifier system in your EHR
instance

This is serial by default, but parallel with the -n flag. Pass this script a value
that identifies a time the job was run. You can also provide it a group name to resume
from. So a run might look like this:

`4-update-groups.sh 2026-Q3`

Or to resume a run that broke for some reason, starting with a dir and advancing
alphabetically from there:

`4-update-groups.sh 2026-Q3 MRN-002`

This is another long running process that you’ll have to monitor (in part because it
has to check all the resources each time, because we don’t get any kind of ‘here’s all
the changes since time x’ from Epic). But when it’s done, you should have ndjson for
all the FHIR resources in the data directory.

We then push this data to S3. We do this because we have short lived AWS access tokens,
and so it will be easier for us to launch an EC2 with an IAM role associated with it,
rather than trying to re-acquire tokens dynamically for what can be a multiday job.

After data has been pushed to S3, we delete all local data that’s no longer in use with 
`./scripts/5-clean-groups.sh`. Run from the refresh directory, it requires no additional args.

Once this is done, we’re finished with smart fetch.

## Running ETL

Once the data is in S3, we’ll need the ETL EC2 we referenced above. SSH into it, and we’ll
create the following two scripts with a similar strategy to the smart fetch section: one
for a single group (`./scripts/6-etl-one.sh`), and one for all groups
(`./scripts/6-etl-all.sh`). Make sure to adjust the bucket name, and the export label,
in both to match your configuration.

The ETL can take a :long: time, on the order of a week or two. We recommend using `screen`
to run the job, so that you’re insulated from ssh timeouts, like the following: 
`screen ./scripts/6-etl-all.sh NICK`

## Building studies

Once the data has been ETLed, then we can start setting up the database. We’ll want to
create a database with `./aws/athena.yaml` (or with the service catalog template we
created using it). using the nickname assigned to the exported datasource, as the
value of the DatasourceName param. The DatasourceLocation should correspond to the S3
location you uploaded your ETLed data to. This will create a db in athena named 
`cumulus_{DatasourceName}_db` in athena.

From here, you can build the core study, using `cumulus_library`, with a command like this:

```bash
cumulus-library build --database cumulus_{DatasourceName}_db \
--workgroup cumulus \
     -t core
```

Once you’ve got the core study built, you should be able to run all others. You would
use the same command as above, just swapping out the parameter passed via the `-t` 
argument with the name of the study you need to run. If a study has other dependencies
(like the coding system studies, such as `loinc` or `rxnorm`, you’ll need to install
those separately - see the study documentation for more information about any other dependencies.
