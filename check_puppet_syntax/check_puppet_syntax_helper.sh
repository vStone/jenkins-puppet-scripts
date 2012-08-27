#!/bin/bash

f="$1";
if [ ! -f "$f" ]; then
  echo "File does not exist: '$f'" 1>&2
  exit 1;
fi

$PUPPET_BIN parser validate $f 2>&1 | while read line; do
    echo "PUPPET_SYNTAX:$f: $line";
done;
exit ${PIPESTATUS[1]}
