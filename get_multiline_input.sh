#!/bin/bash

set -o noglob

lines='[]'
IFS=$'\n'
for line in $1 ; do
  line="${line%%\#*}" # remove comment
  line="$(echo "$line" | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/,"")}1')" # trim
  if [ -n "$line" ]; then
    # on windows, glob works with jq's --arg option
    lines="$(echo "$lines" | jq -c '.+['"$(echo "$line" | jq -R)"']')"
  fi
done
echo "$lines"
