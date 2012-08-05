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
# ,---.,---.,---.,---.
# ,---||    |   |`---.
# `---^`    `---|`---'
#           `---'
# relative path to the repo to inspect.
repo_path="${1-.}";
# Also check the submodules. But warn by default
# (1 to enable, 0 to disable)
check_submodules="${2-1}";
# If checking the submodules, dont warn but error!
# (1 to enable, 0 to disable)
submodules_throw_errors="${3-0}";
# If set to 1, we will not error if the git tree is dirty.
# This also applies to submodules. We want a completely clean tree or don't
# care at all.
ignore_dirty_states="${4-0}";
#==========================================================
# ,----               |    o
# |__. .   .,---.,---.|--- .,---.,---.,---.
# |    |   ||   ||    |    ||   ||   |`---.
# `    `---'`   '`---'`---'``---'`   '`---'

## System error, exits the script and outputs to stderr
# USAGE: syserr <message>
syserr() {
  echo "[git_check] ERROR: $*" 1>&2
  exit 1;
}

## A error has been found. Expose for parsing!
# USAGE: err <message>
err() {
  error_count=1;
  echo "GIT_CHECK:ERROR:$*" 1>&2
}

## Keep track of the number of errors we encounter.
declare -i -x error_count=0;

## Output a info line for git_check.
# USAGE: info <message>
info() {
  echo "GIT_CHECK:INFO:$*";
}

## A submodule warning/error. Depends on $submodules_throws_error.
# USAGE: sub <message>
sub() {
  if [ "$submodules_throw_errors" == "1" ]; then
    err $*;
  else
    echo "GIT_CHECK:WARN:$*" 1>&2
  fi;
}


## Debug function. Only ouputs stuff if SCRIPTDEBUG is set to something/anything.
# USAGE: debug <message>
debug() {
  if [[ x"$SCRIPTDEBUG" != "x" ]]; then
    echo "[debug] $*" 1>&2;
  fi;
}

## Returns the real git dir (if any). If its a submodule, parse the .git file.
# USAGE: get_git_dir <path>
get_git_dir() {
  local path=${1-.};
  local git_path="${path}/.git";
  local real_dir;

  # its a file. maybe from a submodule?
  if [ -f $git_path ]; then
    # check for gitdir: blah
    if `cat $git_path | grep -q 'gitdir\: .\+'`; then
      real_dir=`cat $git_path | grep -o 'gitdir\: .*' | sed -e 's@gitdir: @@'`;
      if [ -d $real_dir ]; then
        git_path=$real_dir;
      fi;
    else
      return 1;
    fi
  fi;
  [ -d $git_path ] || return 1;
  echo $git_path;

}

## Returns the current commit hash of a git repo.
# USAGE: get_current_commit <work-tree> [git_dir]
get_current_commit() {
  local work_tree="${1-.}";
  local git_dir="${2-`get_git_dir $work_tree`}" || return 1;
  git --git-dir=$git_dir --work-tree=$work_tree \
    rev-parse HEAD 2>/dev/null|| return 1;
}

git_check_dirty() {
  local work_tree="${1-.}";
  local git_dir="${2-`get_git_dir $work_tree`}" || return 1;
  [ -z "$( git --git-dir=$git_dir --work-tree=$work_tree status --porcelain )" ] || \
    return 1;

}

## Returns the tag of the commit of a certain git repository.
## This function will return 1 if no tag has been set or no repo is found.
# USAGE: get_tag <work_tree> [commit] [git_dir]
get_tag() {
  local work_tree="${1-.}";
  debug "[tag] work_tree = '$work_tree'";
  local commit="${2-`get_current_commit $work_tree`}" || return 1;
  debug "[tag] commit = '$commit'";
  local git_dir="${3-`get_git_dir $work_tree`}" || return 1;
  debug "[tag] git_dir= '$git_dir'";
  git --git-dir=$git_dir --work-tree=$work_tree \
    describe --tags --exact-match $commit 2>/dev/null || return 1;
}

#==========================================================
# |              o          |
# |    ,---.,---..,---.,---.|
# |    |   ||   |||    ,---||
# `---'`---'`---|``---'`---^`---'
#           `---'
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

[ "$ignore_dirty_states" == "1"  ] || git_check_dirty $repo_path $git_dir || \
  err "MAIN:the git tree seems to be dirty"

tag=`get_tag $repo_path $commit $git_dir` || \
  err "MAIN:could not find any tag on path '$repo_path'";
debug "tag = '$tag'";

if [[ -n $tag ]]; then
  export GIT_TAG="$tag"
fi;
info "MAIN:TAG=${GIT_TAG-unknown}";

if [[ "$check_submodules" == "1" && -f $repo_path/.gitmodules ]]; then

  while read submod_commit submod_dir; do
      submod_path="${repo_path}/${submod_dir}";
      submod_git_dir=`get_git_dir "${submod_path}"` || \
        sub "SUBMODULE:could not detect git repository in '${submod_path}'";
      [ "$ignore_dirty_states" == "1"  ] || \
        git_check_dirty $repo_path $git_dir || \
        err "SUBMODULE:${submod_dir}:SYS:the git submodule tree seems to be dirty"

      submod_tag=`get_tag $submod_path $submod_commit $submod_git_dir` || \
        sub "SUBMODULE:${submod_dir}:SYS:could not find any tag for submodule ${submod_dir}";

      debug "[submodule] submod_tag = '$submod_tag'";

      [ x"$submod_tag" == "x" ] || \
        info "SUBMODULE:${submod_dir}:TAG=$submod_tag";
  done < <( git --git-dir=$git_dir --work-tree=$repo_path submodule status | \
      sed -e 's@^\s*\([a-z0-9]\+\)\s*\([^ ]\+\).*@\1 \2@';
  ) # ends redirect into the loop
fi;


debug "error_count = '$error_count'";
[[ $error_count ==  0 ]] || exit 1;
