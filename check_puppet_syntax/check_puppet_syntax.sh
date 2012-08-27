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


_help() {
  cat <<EOHELP
USAGE: $0 [options] <folder|file> [...]
Checks syntax of all puppet files.

OPTIONS:
  -t, --max-threads NUMBER    The max number of simultaneous threads to use.
                              You can also specify PUPPET_SYNTAX_THREADS as an env
                              variable. Defaults to 5.
  -p --puppet-bin             Path to puppet executable to use. You can also
                              set PUPPET_BIN as an environment variable.
                              Defaults to 'puppet'.
  -e, --erb-bin               Path to erb executable. You can also specify ERB_BIN
                              as an environment variable. Defaults to 'erb'.
  -r, --ruby-bin              Path to ruby executable. You can also specify
                              RUBY_BIN as an environment variable.
                              Defaults to 'ruby'.
  -h, --help                  Display this message and exit.

The argument(s) should be a file or directories containing puppet manifests
and/or ruby templates. Folders are search recursivly for files.

EOHELP
  exit 0;
}



## getopts parsing
if `getopt -T >/dev/null 2>&1` ; [ $? = 4 ] ; then
  true; # Enhanced getopt.
else
  syserr "You are using an old getopt version $(getopt -V)";
fi;

TEMP=`getopt -o -t:p:e:r:h -l max-threads:,puppet-bin:,erb-bin:,ruby-bin:,help -n "$0" -- "$@"`;

if [[ $? != 0 ]]; then
  syserr "Error parsing arguments";
fi;

while [ $# -gt 0 ]; do
  case "$1" in
    -t|--max-threads)     PUPPET_SYNTAX_THREADS="$2"; shift;;
    -p|--puppet-bin)      PUPPET_BIN="$2"; shift;;
    -e|--erb-bin)         ERB_BIN="$2"; shift;;
    -r|--ruby-bin)        RUBY_BIN="$2"; shift;;
    -h|--help)            _help;;
    -*)                   syserr "Command option '$1' not recognized";;
    --)                   shift; break;;
    *)                    break;;
  esac
  shift;
done;

PUPPET_SYNTAX_THREADS="${PUPPET_SYNTAX_THREADS-5}";
PUPPET_BIN="${PUPPET_BIN-puppet}";
ERB_BIN="${ERB_BIN-erb}";
RUBY_BIN="${RUBY_BIN-ruby}";


## No arguments
if [ ${#*} == 0 ]; then
  _help
fi;

echo "${PUPPET_SYNTAX_THREADS}" | grep -q '^[0-9]\+$' || syserr "max threads should be a number";

test_bin() {
  local desc=$1;
  local bin=$2;
  which ${bin} >/dev/null 2>&1  || syserr "${desc} executable (${bin}) not found on path";
  [ -x $( which $bin ) ] || syserr "${desc} executable (${bin}) does not exist or is not executable";
}
test_bin 'puppet' "${PUPPET_BIN}"
test_bin 'erb' "${ERB_BIN}"
test_bin 'ruby' "${RUBY_BIN}"


_ERB_HELPER="$(cd $(dirname "$0"); pwd)/check_puppet_erb_helper.sh";
test_bin 'erb_helper_script' "${_ERB_HELPER}";

_PUPPET_HELPER="$(cd $(dirname "$0"); pwd)/check_puppet_syntax_helper.sh";
test_bin 'puppet_helper_script' "${_PUPPET_HELPER}";

#==========================================================
# |              o          |
# |    ,---.,---..,---.,---.|
# |    |   ||   |||    ,---||
# `---'`---'`---|``---'`---^`---'
#           `---'

echo "Checking puppet syntax (Using $PUPPET_SYNTAX_THREADS threads)"
find $* -iname '*.pp' | xargs --no-run-if-empty -t -n1 -P${PUPPET_SYNTAX_THREADS} -I file \
  sh -c "PUPPET_BIN='${PUPPET_BIN}' $_PUPPET_HELPER file" || puppet_error="1";

echo "Puppet error: $puppet_error";

echo "Checking ruby template syntax (Using $PUPPET_SYNTAX_THREADS threads)"
find $* -iname '*.erb' | xargs --no-run-if-empty -t -n1 -P${PUPPET_SYNTAX_THREADS} -I file \
  sh -c "RUBY_BIN='${RUBY_BIN}' ERB_BIN='${ERB_BIN}' $_ERB_HELPER file" || ruby_error="1";

if [ "$puppet_error" == 1 ]; then
  echo "Puppet syntax error detected.";
  failed=1;
fi;

if [ "$ruby_error" == "1" ]; then
  echo "Ruby template syntax error detected.";
  failed=1;
fi;

if [ "$failed" == "1" ]; then
  echo FAILED
  exit 1;
fi;
