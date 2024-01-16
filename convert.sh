#!/bin/bash

cd /app/input
files=$(ls *.pdf *.cbr 2>/dev/null)
if [[ -z $files ]]; then
  echo "No files found, exiting."
else
  while read file; do
    echo "Converting $file"
    cbconvert convert --outdir /app/output/ "$file" < /dev/null
  done< <(echo "$files")
fi