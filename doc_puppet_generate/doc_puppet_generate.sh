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
USAGE: $0 <options>

  -o, --output-dir DIR    Directory to put the files in. Defaults to
                          doc/ in the current directory.
  -f, --force             Force output even if the output directory
                          already exists.
  -n, --no-postprocess    Postprocessing will use some sed magic
                          to fix paths and filenames in the docs
                          so that documentation seems to be based
                          on the /etc/puppet structure in stead of
                          the working directory of your module.
                          With this flag, you disable this behaviour.
  -w, --workspace PATH    This is the part that gets stripped off
                          during the postprocessing. It defaults
                          to the current directory you are running
                          this script from. You can also change this
                          by setting the WORKSPACE environment variable.
  -s, --single            Indicate that the workspace contains a single
                          puppet module. If not, we will assume its a
                          directory where each subfolder contains a puppet
                          module.
  -h, --help              Show this message and exit.

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


TEMP=`getopt -o -o:nw:hfs \
  -l output-dir:,no-postprocess,workspace:,help,force,single -n "$@" -- "$@"`;

if [[ $? != 0 ]]; then
  syserr "Error parsing arguments";
fi;

while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output-dir)      DOC_OUTPUT="$2"; shift;;
    -n|--no-postprocess)  NO_POST=1;;
    -w|--workspace)       WORKSPACE="$2"; shift;;
    -f|--force)           FORCE=1;;
    -h|--help)            _help;;
    -*)                   syserr "Command option '$1' not recognized";;
    --)                   shift; break;;
    *)                    break;;
  esac;
  shift;
done;

DOC_OUTPUT="${DOC_OUTPUT-./doc}"
NO_POST="${NO_POST}";
WORKSPACE="${WORKSPACE-.}";
FORCE="${FORCE}"

## expand workspace
WORKSPACE="`readlink -f ${WORKSPACE}`"

echo "WORKSPACE: $WORKSPACE"
exit 0;
[[ -d $DOC_OUTPUT && ! "$FORCE" ]] && \
  syserr "Output directory '$DOC_OUTPUT' already exists. use --force to force"
[ -d $DOC_OUTPUT ] || mkdir -p $DOC_OUTPUT

# |              o          |
# |    ,---.,---..,---.,---.|
# |    |   ||   |||    ,---||
# `---'`---'`---|``---'`---^`---'
#           `---'

## setup the environment

## Generate docs
puppet doc --mode rdoc --manifestdir manifests/ --modulepath ./modules/ --outputdir doc

## Fix docs to how I want them bitches
##! [ -d ${WORKSPACE}/doc/files/puppet ] && mkdir -v ${WORKSPACE}/doc/files/puppet;

if [ -d ${WORKSPACE}/doc/files/${WORKSPACE}/modules ]; then
  mv -v "${WORKSPACE}/doc/files/${WORKSPACE}/modules" "${WORKSPACE}/doc/files/modules"
fi;
echo "WORKSPACE: '${WORKSPACE}'"
grep -l -R ${WORKSPACE} * | while read fname; do sed -i "s@${WORKSPACE}/@/@g" $fname; done;
