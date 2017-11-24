#!/bin/bash

version=$1; shift
s3=$1; shift
if [ -z "$version" ]; then
  echo >&2 "Usage: $0 <version> [<bucket>[/<prefix>]]"
  exit 1
fi

if [ -z "$PYENV_ROOT" ]; then
  echo >&2 "https://github.com/pyenv/pyenv is required!"
  exit 2
fi

set -e

venv=$(date +"%Y%m%d%H%M%S")
ROOT="$PYENV_ROOT/versions/$venv"
trap 'rm -rf "$ROOT"' ERR EXIT
pyenv virtualenv "$venv"
PYENV_VERSION="$venv" pip install -r requirements.txt

zip="isengard-$version.zip"
scratch="$ROOT/$zip"
zip "$scratch" s3apt.py config.py
( cd "$ROOT/lib/python2.7/site-packages" && exec zip -r "$scratch" * )
mv -f -v "$scratch" "$zip"

[ -n "$s3" ] && aws s3 cp "$zip" "s3://${s3#s3\://}"
