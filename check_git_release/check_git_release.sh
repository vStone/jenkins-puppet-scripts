#!/bin/bash
#
# This script should be used in a release branch.
# It checks if a (git) tag has been set on the current branch. This should be
# the master branch.
#
# If there are any submodules defined, these will also be checked but throw
# warnings by default. There are some arguments available to change this
# behaviour. See below.
#

#==========================================================
# ,----               |    o
# |__. .   .,---.,---.|--- .,---.,---.,---.
# |    |   ||   ||    |    ||   ||   |`---.
# `    `---'`   '`---'`---'``---'`   '`---'

## External scripts
#source $(cd $(dirname "$0")/../common/; pwd)/functions.sh || \
#  syserr "Failed to load required common/functions.sh library.";
source $(cd $(dirname "$0"); pwd)/check_git_release_lib.sh || \
  syserr "Failed to load required check_git_release_lib.sh library.";

## Keep track of the number of errors we encounter.
declare -i errors=0;
## A error has been found. Expose for parsing!
# USAGE: err <message>
err() {
  errors=1;
  echo "GIT_CHECK:ERROR:$*" 1>&2
}

## Output a warning line for git_check
# USAGE: warn <message>
warn() {
  echo "GIT_CHECK:WARN:$*" 1>&2
}

## Output a info line for git_check.
# USAGE: info <message>
info() {
  echo "GIT_CHECK:INFO:$*";
}

## A submodule warning/error. Depends on $submodules_throws_error.
# USAGE: sub <message>
sub() {
  if [ "$submods_tag_error" == "1" ]; then
    err $*;
  else
    warn $*
  fi;
}


## Debug function. Only ouputs stuff if SCRIPTDEBUG is set to something/anything.
# USAGE: debug <message>
debug() {
  if [ "$SCRIPTDEBUG" ]; then
    echo "[debug] $*" 1>&2;
  fi;
}

_help() {
  cat <<EOHELP
USAGE: $0 [options] <git repo>
Check if a tag has been set on the repository and/or his submodules.

OPTIONS:
  -e, --dirty-tree-error 1|0      If enabled, a dirty tree will throw an error.
                                  If a submodule is dirty, the main tree is
                                  also dirty so this will automaticly fail.
                                  Defaults to enabled (1).
  -m, --check-submodules 1|0      Enable or disable checking of submodules.
                                  Defaults to enabled (1).
  -t, --submods-tag-error 1|0     If a submodule has no tag set, throw an error
                                  or just warn. Defaults to warning only (0).
  -d, --debug                     Enable debugging of the script.
                                  Debugging is also enabled when a SCRIPTDEBUG
                                  environment variable has been set with a
                                  non-empty value.
  -h, --help                      Show this message and exit.

The argument should be the path to a git repository. This can also be a
specific submodule. It no path is provided, we default to the current dir.

EOHELP
  exit 0;
}


## getopts parsing
if `getopt -T >/dev/null 2>&1` ; [ $? = 4 ] ; then
  true; # Enhanced getopt.
else
 syserr "You are using an old getopt version $(getopt -V)";
fi;

TEMP=`getopt -o -e:m:t:dh \
  --long dirty-tree-error:,check-submodules:,submods-tag-error:,debug,help \
  -n "$0" -- "$@"`;

if [[ $? != 0 ]]; then
  syserr "Error parsing arguments"
fi;

while [ $# -gt 0 ]; do
  case "$1" in
    -e|--dirty-tree-error)  dirty_tree_error="$2"; shift;;
    -m|--check-submodules)  check_submodules="$2"; shift;;
    -t|--submods-tag-error) submods_tag_error="$2"; shift;;
    -h|--help)              _help;;
    -d|--debug)             SCRIPTDEBUG=1;;
    -*)                     syserr "Command option not recognized";;
    --)                     shift; break;;
    *)                      break;;
  esac
  shift;
done;

#==========================================================
# ,---.,---.,---.,---.
# ,---||    |   |`---.
# `---^`    `---|`---'
#           `---'

# Git repository to check
repo_path="${1-.}"
# Check submodules
check_submodules="${check_submodules-1}";
submods_tag_error="${submods_tag_error-0}";
# If set to 1, we will not error if the git tree is dirty.
# This also applies to submodules. We want a completely clean tree or don't
# care at all.
ignore_dirty_states="${4-0}";
dirty_tree_error="${dirty_tree_error-1}";


#==========================================================
# |              |
# |--- ,---.,---.|--- ,---.
# |    |---'`---.|    `---.
# `---'`---'`---'`---'`---'
#

debug "repo_path = '$repo_path'";
## Is it even a directory that exists?
[ -d $repo_path ] || syserr "path '$repo_path' does not exist";

## Is this a git repo? and if it is, what is the git dir?
git_dir=`get_git_dir $repo_path` || \
  syserr "path '$repo_path' does not seem to be a git repository";
debug "git_dir = '$git_dir'";

## Get the commit hash were are on.
commit=`get_current_commit $repo_path $git_dir` || \
  syserr "could not get current commit on path '$repo_path'";
debug "current commit = '$commit'";

#==========================================================
# |              o          |
# |    ,---.,---..,---.,---.|
# |    |   ||   |||    ,---||
# `---'`---'`---|``---'`---^`---'
#           `---'
#

if ! git_check_dirty $repo_path $git_dir; then
  if [ "$dirty_tree_error" == "1" ]; then
    err "MAIN:SYS:the git tree seems to be dirty"
  else
    warn "MAIN:SYS:the git tree seems to be dirty"
  fi;
fi;

tag=`get_tag $repo_path $commit $git_dir` || \
  err "MAIN:SYS:could not find any tag on path '$repo_path'";
debug "tag = '$tag'";

[ "$tag" ] || tag="unknown";
info "MAIN:TAG=${tag-unknown}";

if [[ "$check_submodules" == "1" && -f $repo_path/.gitmodules ]]; then
  SUBMODULES=$( cd $repo_path; git submodule status | \
    sed -e 's@^\s*\([a-z0-9]\+\)\s*\([^ ]\+\).*@\1 \2@';
  );

  while read submod_commit submod_dir; do
    submod_path="${repo_path}/${submod_dir}";
    submod_git_dir=`get_git_dir "${submod_path}"` || \
      sub "SUBMODULE:could not detect git repository in '${submod_path}'";

    if ! git_check_dirty $submod_path $submod_git_dir; then
      debug "[submodule] is dirty"
      if [ "$dirty_tree_error" == "1" ]; then
        err "SUBMODULE:${submod_dir}:SYS:the git submodule tree seems to be dirty"
      else
        warn "SUBMODULE:${submod_dir}:SYS:the git submodule tree seems to be dirty";
      fi;
    fi;
    submod_tag=`get_tag $submod_path $submod_commit $submod_git_dir` || \
      sub "SUBMODULE:${submod_dir}:SYS:could not find any tag for submodule ${submod_dir}";
    debug "[submodule] errors = '$errors'";
    debug "[submodule] submod_tag = '$submod_tag'";

    [ "$submod_tag" ] && \
      info "SUBMODULE:${submod_dir}:TAG=$submod_tag";
  done <<< "$SUBMODULES"
fi;


debug "errors = '$errors'";
[ $errors == 0 ] || exit 1;
