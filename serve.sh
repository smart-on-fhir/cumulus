#!/bin/sh
set -e

# This script builds the docs and runs a local server for testing them.

bundle exec jekyll serve --source docs
