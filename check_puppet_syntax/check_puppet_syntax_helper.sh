#!/bin/bash

f="$1";
if [ ! -f "$f" ]; then
  echo "File does not exist: '$f'" 1>&2
  exit 1;
fi

if [ "${PUPPET_STOREDCONFIGS-0}" == "1" ]; then
  PUPPET_OPTS="${PUPPET_OPTS} --storeconfigs"
fi;

$PUPPET_BIN parser validate $PUPPET_OPTS --color false --render-as s $f 2>&1 | while read line; do
    echo "PUPPET_SYNTAX:$f: $line";
done;
exit ${PIPESTATUS[0]}
