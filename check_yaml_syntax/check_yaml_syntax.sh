#!/bin/bash

#==========================================================
# ,----               |    o
# |__. .   .,---.,---.|--- .,---.,---.,---.
# |    |   ||   ||    |    ||   ||   |`---.
# `    `---'`   '`---'`---'``---'`   '`---'
#

syserr() {
  echo "[$0] ERROR: $*" 1>&2
  exit 1;
}

test_bin() {
  local desc=$1;
  local bin=$2;
  which ${bin} >/dev/null 2>&1  || syserr "${desc} executable (${bin}) not found on path";
  [ -x $( which $bin ) ] || syserr "${desc} executable (${bin}) does not exist or is not executable";
}

_help() {
  cat <<EOHELP
USAGE: $0 [options] <folder|file> [...]
Checks syntax of yaml files.

OPTIONS:
  -t, --max-threads NUMBER    The max number of simultaneous threads to use.
                              You can also specify YAML_SYNTAX_THREADS as an env
                              variable. Defaults to 5.
  -r, --ruby-bin              Path to ruby executable. You can also specify
                              RUBY_BIN as an environment variable.
                              Defaults to 'ruby'.
  -h, --help                  Display this message and exit.

The argument(s) should be a file or directories containing yaml files.
Folders are checked recursively.

EOHELP
  exit 0;
}

## getopts parsing
if `getopt -T >/dev/null 2>&1` ; [ $? = 4 ] ; then
  true; # Enhanced getopt.
else
  syserr "You are using an old getopt version $(getopt -V)";
fi;


TEMP=`getopt -o -t:r:h -l max-threads:,ruby-bin:,help -n "$0" -- "$@"`;

if [[ $? != 0 ]]; then
  syserr "Error parsing arguments";
fi;

while [ $# -gt 0 ]; do
  case "$1" in
    -t|--max-threads)     YAML_SYNTAX_THREADS="$2"; shift;;
    -r|--ruby-bin)        RUBY_BIN="$2"; shift;;
    -h|--help)            _help;;
    -*)                   syserr "Command option '$1' not recognized";;
    --)                   shift; break;;
    *)                    break;;
  esac
  shift;
done;

YAML_SYNTAX_THREADS="${YAML_SYNTAX_THREADS-5}";
RUBY_BIN="${RUBY_BIN-ruby}";

## No arguments
if [ ${#*} == 0 ]; then
  _help
fi;

echo "${YAML_SYNTAX_THREADS}" | grep -q '^[0-9]\+$' || syserr "max threads should be a number";

test_bin 'ruby' "${RUBY_BIN}"

_YAML_HELPER="$( cd $(dirname "$0"); pwd)/check_yaml.rb";
test_bin 'check_yaml' "${_YAML_HELPER}";

#==========================================================
# |              o          |
# |    ,---.,---..,---.,---.|
# |    |   ||   |||    ,---||
# `---'`---'`---|``---'`---^`---'
#

find $* -iname '*.yaml' | xargs --no-run-if-empty -t -n1 -P${YAML_SYNTAX_THREADS} -I file \
  sh -c "$RUBY_BIN $_YAML_HELPER file" 2>&1  || yaml_error="1";

if [ "$yaml_error" == 1 ]; then
  echo "YAML Syntax error detected.";
  exit 1;
fi;
