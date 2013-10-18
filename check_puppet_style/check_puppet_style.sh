#!/bin/bash

#==========================================================
# ,----               |    o
# |__. .   .,---.,---.|--- .,---.,---.,---.
# |    |   ||   ||    |    ||   ||   |`---.
# `    `---'`   '`---'`---'``---'`   '`---'
#

syserr() {
  echo "$0: ERROR: $*" 1>&2
  exit 1;
}

_help() {
  cat <<EOHELP
USAGE: $0 <options> <folder|file> [...]
Checks your puppet manifests with puppet-lint.

OPTIONS:
  -t, --max-threads NUMBER      The maximum number of simultaneous threads to
                                use. You can also specify PUPPET_LINT_THREADS as an
                                environment variable. Defaults to 5.
  -p, --puppet-lint-bin PATH    Path to puppet-lint executable. Can also be
                                specified as an env variable PUPPET_LINT_BIN.
                                Defaults to 'puppet-lint'.
  -l, --log-format              Override the log format. The default log format
                                has been setup to use with the jenkins
                                warnings-plugin (puppet-lint).
  -s, --skip-tests              Skips the tests directory in puppet modules.
                                You can also specify PUPPET_LINT_SKIP_TESTS as an
                                non empty environment variable.
  -e, --skip-examples           Skips the examples directory in puppet modules.
                                You can also specify PUPPET_LINT_SKIP_EXAMPLES as an
                                non empty environment variable.
  -c, --skip-custom             Custom pattern to skip. This is added with ! -iwholename
                                to the find command we are building. You can specify
                                this option multiple times if needed.
  -f, --fail-on-error           By default, this script always exits with an
                                exit status of 0. If this is enabled, we will
                                exit with a status of 1 if any errors are
                                detected by puppet lint. You can also specify
                                a non empty environment variable PUPPET_LINT_FAILS_ERROR.
  -w, --fail-on-warning         Exit with a status of 1 if a warning is
                                detected by puppet lint. This implies
                                fail-on-error too. You can also specify a non
                                empty environment variable FAIL_ON_WARN.
  -x, --exclude-checks          A comma seperated list of puppet lint checks to
                                exclude. You can check puppet-lint --help for all
                                available tests.
                                Example: '-x ensure_first_param,80chars,...'
  -h, --help                    Display this message and exit.

The argument(s) should be a file or directories containing puppet manifests.
Folders are search recursivly for files.

EOHELP
  exit 0;
}



#==========================================================
#           |              |
# ,---.,---.|--- ,---.,---.|--- ,---.
# |   ||---'|    |   ||   ||    `---.
# `---|`---'`---'`---'|---'`---'`---'
# `---'               |


## getopts parsing
if `getopt -T >/dev/null 2>&1` ; [ $? = 4 ] ; then
  true; # Enhanced getopt.
else
  syserr "You are using an old getopt version $(getopt -V)";
fi;


TEMP=`getopt -o -p:sec:t:hl:fwx: \
  -l puppet-lint-bin:skip-tests,skip-examples,skip-custom:,max-threads,help,log-format,fail-on-error,fail-on-warning,exclude-checks -n "$0" -- "$@";`

if [[ $? != 0 ]]; then
  syserr "Error parsing arguments";
fi;


while [ $# -gt 0 ]; do
  case "$1" in
    -t|--max-threads)         echo "$2" | grep -q '^[0-9]\+$' || \
                                syserr "max-threads should be a number";
                              PUPPET_LINT_THREADS="$2"; shift;;
    -p|--puppet-lint-bin)     [ -f $2 ] || \
                                syserr "puppet-lint-bin: file does not exist.";
                              PUPPET_LINT_BIN="$2"; shift;;
    -l|--log-format)          PUPPET_LINT_LOG_FORMAT="$2"; shift;;
    -s|--skip-tests)          PUPPET_LINT_SKIP_TESTS="1";;
    -e|--skip-examples)       PUPPET_LINT_SKIP_EXAMPLES="1";;
    -c|--skip-custom)         PUPPET_LINT_SKIP_CUSTOM="${PUPPET_LINT_SKIP_CUSTOM}|$2"; shift;;
    -f|--fail-on-error)       PUPPET_LINT_FAILS_ERROR="1";;
    -w|--fail-on-warning)     PUPPET_LINT_FAILS_WARNING="1";;
    -x|--exclude-checks)      PUPPET_LINT_EXCLUDE_CHECKS="$2"; shift;;
    -h|--help)                _help;;
    -*)                       syserr "Command option '$1' not recognized";;
    --)                       shift; break;;
    *)                        break;;
  esac;
  shift;
done;

if [ $# == 0 ]; then
  _help;
fi

PUPPET_LINT_THREADS="${PUPPET_LINT_THREADS-5}";
PUPPET_LINT_BIN="${PUPPET_LINT_BIN-puppet-lint}";

PUPPET_LINT_SKIP_TESTS="${PUPPET_LINT_SKIP_TESTS}";
PUPPET_LINT_SKIP_EXAMPLES="${PUPPET_LINT_SKIP_EXAMPLES}";
PUPPET_LINT_SKIP_CUSTOM="${PUPPET_LINT_SKIP_CUSTOM}";

PUPPET_LINT_LOG_FORMAT="${PUPPET_LINT_LOG_FORMAT}"
[ ! "${PUPPET_LINT_LOG_FORMAT}" ] && PUPPET_LINT_LOG_FORMAT="%{path}:%{linenumber}:%{check}:%{KIND}:%{message}"

PUPPET_LINT_FAILS_WARNING="${PUPPET_LINT_FAILS_WARNING}";
PUPPET_LINT_FAILS_ERROR="${PUPPET_LINT_FAILS_ERROR-${PUPPET_LINT_FAILS_WARNING}}";

PUPPET_LINT_EXCLUDE_CHECKS="${PUPPET_LINT_EXCLUDE_CHECKS}";

## Accept 1, true, yes as boolean values. anything else is false really.
[[ "${PUPPET_LINT_SKIP_TESTS}" == "true" || "${PUPPET_LINT_SKIP_TESTS}" == "yes" ]] && PUPPET_LINT_SKIP_TESTS="1";
[[ "${PUPPET_LINT_SKIP_EXAMPLES}" == "true" || "${PUPPET_LINT_SKIP_EXAMPLES}" == "yes" ]] && PUPPET_LINT_SKIP_EXAMPLES="1";
[[ "${PUPPET_LINT_FAILS_WARNING}" == "true" || "${PUPPET_LINT_FAILS_WARNING}" == "yes" ]] && PUPPET_LINT_FAILS_WARNING="1";
[[ "${PUPPET_LINT_FAILS_ERROR}" == "true" || "${PUPPET_LINT_FAILS_ERROR}" == "yes" ]] && PUPPET_LINT_FAILS_ERROR="1";


## TEST SETTINGS/ARGUMENTS ##
echo "${PUPPET_LINT_THREADS}" | grep -q '^[0-9]\+$' || syserr "max threads should be a number";

test_bin() {
  local desc=$1;
  local bin=$2;
  which ${bin} 2>&1 >/dev/null || syserr "${desc} executable (${bin}) not found on path";
  [ -x $( which $bin ) ] || syserr "${desc} executable (${bin}) does not exist or is not executable";
}

test_bin 'puppet-lint' "${PUPPET_LINT_BIN}"

echo "Checking puppet style (Using $PUPPET_LINT_THREADS threads):"
_find="find $* -iname '*.pp'"
if [ "$PUPPET_LINT_SKIP_TESTS" == "1" ]; then
  _find="${_find} ! -iwholename '*/tests/*'"
fi;
if [ "$PUPPET_LINT_SKIP_EXAMPLES" == "1" ]; then
  _find="${_find} ! -iwholename '*/examples/*'"
fi;
if [ "$PUPPET_LINT_SKIP_CUSTOM" ]; then
  set -f
  for custom in $( echo "${PUPPET_LINT_SKIP_CUSTOM}" | tr '|' "\n"); do
    [ "$custom" ] && _find="${_find} ! -iwholename '${custom}'"
  done;
  set +f
fi;


warning_count=0
error_count=0

_puppet_lint="${PUPPET_LINT_BIN} --log-format '${PUPPET_LINT_LOG_FORMAT}'"
if [ "$PUPPET_LINT_EXCLUDE_CHECKS" ]; then
  for check in $( echo "$PUPPET_LINT_EXCLUDE_CHECKS" | tr ',' "\n") ; do
    _puppet_lint="${_puppet_lint} --no-${check}-check";
  done
fi;

eval $_find | xargs --no-run-if-empty -n1 -P${PUPPET_LINT_THREADS} \
  $_puppet_lint --log-format "${PUPPET_LINT_LOG_FORMAT}" | (
  while read line; do
    echo $line | grep -q ':WARNING:' && let "warning_count++"
    echo $line | grep -q ':ERROR:' && let "error_count++"
    echo $line
  done
  echo "Puppet lint finished";
  echo "- Error count: ${error_count}";
  echo "- Warn count: ${warning_count}";
  if [[ "$PUPPET_LINT_FAILS_ERROR" == "1" && $error_count -gt 0 ]]; then
    echo "=> PUPPET_LINT_FAILS_ERROR enabled and error_count above 0";
    exit 1;
  fi;
  if [[ "$PUPPET_LINT_FAILS_WARNING" == "1" && $warning_count -gt 0 ]]; then
    echo "=> PUPPET_LINT_FAILS_WARNING enabled and warning_count above 0";
    exit 1;
  fi;
  exit 0;
) || exit $?

