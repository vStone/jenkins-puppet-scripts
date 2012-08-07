#!/bin/bash

SOURCE="$1";
SKIP_SYNTAX="${SKIP_SYNTAX-false}"


#==========================================================
# ,----               |    o
# |__. .   .,---.,---.|--- .,---.,---.,---.
# |    |   ||   ||    |    ||   ||   |`---.
# `    `---'`   '`---'`---'``---'`   '`---'
#

syserr() {
  echo "[puppet_syntax] ERROR: $*" 1>&2
  exit 1;
}


_help() {
  cat <<EOHELP
USAGE: $0 [options] <folder|file> [...]
Checks syntax of all puppet files.

OPTIONS:
  -t, --max-threads NUMBER    The maximum number of simultaneous threads to use.
                              You can also specify MAX_THREADS as an environment
                              variable. max_threads defaults to 5.
  -p --puppet-bin             Path to puppet executable to use. You can also set
                              PUPPET as an environment variable. Defaults to 'puppet'.
  -e, --erb-bin               Path to erb executable. You can also specify ERB as
                              an environment variable. Defaults to 'erb'.
  -r, --ruby-bin              Path to ruby executable. You can also specify RUBY as
                              an environment varialbe. Defaults to 'ruby'.
  -h, --help                  Display this message and exit.

The argument(s) should be a file or directories containing puppet manifests.
Folders are search recursivly for puppet files.

EOHELP
  exit 0;
}

## No arguments
if [ ${#*} == 0 ]; then
  _help
fi;


## getopts parsing
if `getopt -T >/dev/null 2>&1` ; [ $? = 4 ] ; then
  true; # Enhanced getopt.
else
  syserr "You are using an old getopt version $(getopt -V)";
fi;

TEMP=`getopt -o -t:p:e:r:h --long max-threads,puppet-bin,erb-bin,ruby-bin,help -n "$0" -- "$@"`;

if [[ $? != 0 ]]; then
  syserr "Error parsing arguments";
fi;

while [ $# -gt 0 ]; do
  case "$1" in
    -t|--max-threads)     MAX_THREADS="$2"; shift;;
    -p|--puppet-bin)      PUPPET="$2"; shift;;
    -e|--erb-bin)         ERB="$2"; shift;;
    -r|--ruby-bin)        RUBY="$2"; shift;;
    -h|--help)            _help;;
    -*)                   syserr "Command option '$1' not recognized";;
    --)                   shift; break;;
    *)                    break;;
  esac
  shift;
done;

MAX_THREADS="${MAX_THREADS-5}";
PUPPET="${PUPPET-puppet}";
ERB="${ERB-erb}";
RUBY="${RUBY-ruby}";

#==========================================================
# |              o          |
# |    ,---.,---..,---.,---.|
# |    |   ||   |||    ,---||
# `---'`---'`---|``---'`---^`---'
#           `---'

echo "Checking puppet syntax (Using $MAX_THREADS threads)"
find $* -iname '*.pp' | xargs --no-run-if-empty -t -n1 -P${MAX_THREADS} \
  $PUPPET parser validate --ignoreimport || exit 1;

echo "Checking ruby template syntax (Using $MAX_THREADS threads)"
find $* -iname '*.erb' | xargs --no-run-if-empty -t -n1 -P${MAX_THREADS} \
  sh -c "${ERB} -x -T '-' \$1 | ${RUBY} -c" || exit 1;
