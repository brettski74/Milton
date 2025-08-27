#!/bin/bash

PARAMS=""
SEP=""

while [ -n "$1" ]; do
  if [ "$1" == '-d' ]; then
    shift
    PARAMS="$PARAMS$SEP\"device\":\"$1\""
  elif [ "$1" == '-a' ]; then
    shift
    PARAMS="$PARAMS$SEP\"ambient\":\"$1\""
  elif [ "$1" == '-p' ]; then
    shift
    PARAMS="$PARAMS$SEP\"profile\":\"$1\""
  else
    echo "Error: Unrecognized option '$1'" >&2
    exit 1
  fi

  SEP=,

  shift
done

P="{\"parameters\":{$PARAMS}}"
echo request-body:
echo "$P"
curl -X POST -d "$P" http://localhost:3000/api/commands/reflow
echo ""
