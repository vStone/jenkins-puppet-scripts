#!/bin/bash
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
  local commit="${2-`get_current_commit $work_tree`}" || return 1;
  local git_dir="${3-`get_git_dir $work_tree`}" || return 1;
  git --git-dir=$git_dir --work-tree=$work_tree \
    describe --tags --exact-match $commit 2>/dev/null || return 1;
}

