#!/bin/bash

version=$1; shift
s3=$1; shift
if [ -z "$version" ]; then
  echo >&2 "Usage: $0 <version> [<bucket>[/<prefix>]]"
  exit 1
fi

set -e

ROOT=$(mktemp -d --tmpdir=$PWD)
trap 'rm -rf "$ROOT"' ERR EXIT
virtualenv "$ROOT"
. "$ROOT/bin/activate"
pip install -r requirements.txt

zip="isengard-$version.zip"
scratch="$ROOT/$zip"
zip "$scratch" s3apt.py config.py
( cd "$ROOT/lib/python3.8/site-packages" && exec zip -r "$scratch" * )
mv -f -v "$scratch" "$zip"

[ -n "$s3" ] && aws s3 cp "$zip" "s3://${s3#s3\://}"
