#!/bin/bash

f="$1";
if [ ! -f "$f" ]; then
  echo "File does not exist: '$f'" 1>&2
  exit 1;
fi

$ERB_BIN -x -S 0 -T '-' $f | $RUBY_BIN -c 2>&1 | while read line; do
  echo "$f: $line";
done;
exit ${PIPESTATUS[1]}
