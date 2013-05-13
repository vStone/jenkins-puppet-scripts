#!/bin/bash

VERSION="0.1"

#==========================================================
# ,----               |    o
# |__. .   .,---.,---.|--- .,---.,---.,---.
# |    |   ||   ||    |    ||   ||   |`---.
# `    `---'`   '`---'`---'``---'`   '`---'
#

if ! source $(cd $(dirname "$0"); pwd)/../common/functions.sh; then
  echo "Failed to load required common/functions.sh library." 1>&2
  exit 1;
fi;

if ! source $(cd $(dirname "$0"); pwd)/../common/git.sh; then
  echo "Failed to load required common/git.sh library." 1>&2
  exit 1
fi;

_environment_variables=(
  PPKG_GENERAL=--------------------------------
  PPKG_ENVIRONMENT='Set the environment name.'
  PPKG_VERSION='Set the package version.'
  PPKG_ITERATION='Set the package iteration.'
  PPKG_TYPE='Package type to produce.'
  PPKG_NAME_PREFIX='This will be added in front of the default name: <name prefix>-puppet-tree-<environment>'
  PPKG_NAME_BASE='The base of the package name. This is prefixed by the name prefix and the environment is appended.'
  PPKG_TARGET='target directory to package'.
  PPKG_GIT_ROOT='if you only build a subdir from your repository, set this to the repo root.'
  PPKG_META_INFO=--------------------------------
  PPKG_VENDOR='The vendor providing the package'
  PPKG_DESCRIPTION='Description of the package'
  PPKG_CATEGORY='Category to use for package'
  PPKG_MAINTAINER='maintainer of the package.'
  PPKG_URL='url of the package'
  PPKG_SYS=--------------------------------
  PPKG_DEPENDENCIES='comma seperated list of dependencies'
  PPKG_CONFIGS='comma seperated list of files to mark as configuration. we will prepend the PREFIX to relative files'
  PPKG_EXCLUDES='files to exclude from the package.'
  PPKG_PROVIDES='comma seperated list of provides'
  PPKG_INTERNALS=--------------------------------
  PPKG_MAP_ENVIRONMENTS='A list of branch name to environment mappings. Must be <git branch>=<environment>. Seperate multiple values with spaces. This does not work for the GIT_RELEASE_BRANCH since that relies on the GIT_TAG for the environment name.'
  PPKG_GIT_RELEASE_BRANCH='name of the branch which contains releases'
  PPKG_NO_RELEASE='set this to something if this is NOT a release. This resolves some issues where a tag is in multiple branches'
  PPKG_GIT_FORCE_BRANCH='force to only build this branch. fails if the current commit is not on that branch'
  PPKG_DEFAULT_VERSION='override the default version (which is 1.0)'
  PPKG_PREFIX='override the prefix (not recommended).'
  PPKG_NAME='override the package name (not recommended).'

)
_max_env_len="20"
_help_environment_var() {
  local key
  local value
  local env
  local strlen

  for env in "${_environment_variables[@]}"; do
    key="${env%%=*}";
    value="${env##*=}";
    strlen=$(( $_max_env_len - `echo $key | wc -c` ))
    if [ "${value}" == "--------------------------------" ]; then
      echo "";
      continue;
    fi;
    printf "    %s='' %${strlen}s# %s\n" "$key" " " "$value";
  done
}


_help() {
  cat <<EOHELP
USAGE: $0 [options] <folder> [...]
Packages a puppet tree as an environment.

DESCRIPTION:
  This script has been written to package a puppet tree to use as an split
  off environment. In short, the directory provided as an argument should
  be the root of your puppet tree. It will be installed in a folder with the
  following format:

    /etc/puppet/environments/<environment-name>

  The environment name will be build with the following logic in mind:
    * Is this a git repository? If not, you should provide the environment name
      yourself.
    * We're NOT on the master branch? If not, we will use the branch name as
      the environment name. If a tag is set on the branch, we will append it
      to the environment name (ex: <branch name>-<branch tag>). The version
      will be the one provided or the default version '1.0'.
    * On the master branch?
      * A git tag has been set? Well, you should really do this.
        We'll warn about this and set the environment name to master.
      * You have a git tag, this will be the environment name. The version
        will be the version provided or the default version '1.0'.

  Package iteration? If you do not provide the number, this will be either 0
  or if the BUILD_NUMBER environment variable is set, we will use that instead.
  BUILD_NUMBER is an environment variable that is automatically set by Jenkins.

PPKG-SETTINGS FILE

  If you have a file called .ppkg-settings in the folder to package,
  it will be sourced before processing begins. You can use this file to specify
  environment variables for this build. This file will be excluded from
  packaging. Note that anything here will override any setting you provide (except the
  target folder to package). You can work arround this by using (for example):
  PPKG_NAME="${PPKG_NAME-myname}".

OPTIONS:

  -e, --environment           Overrides the name of the environment to use.
                              You can set this to 'GIT_BRANCH' to use the git
                              branch (if available) as the environment name.
                              This will alter the default behaviour by NOT
                              appending (or using) the git tag.
                              Works well together  with 'GIT_TAG' as version
                              number. To also use this for your release branch,
                              change PPKG_GIT_RELEASE_BRANCH to sth that would
                              not be used.
                              ex: '_this_release_uses_alternative_naming_'.
  -v, --version               Specify the package version. Defaults to 1.0.
                              You can set this to 'GIT_TAG' if you prefer
                              to use that as the default version number instead
                              of 1.0.
  -i, --iteration             The iteration number to use.
  -t, --type                  Package type to build. Defaults to rpm.
  -h, --help                  Display this message and exit.


ARGUMENT:
  Path of the puppet tree to package. This has no default. If you want to
  package the current working directory, you have to explictly set it to '.'

ENVIRONMENT VARIABLES:
  You can alter the behaviour a lot more by using the following environment
  variables before calling the script. These include the possibility to
  override values you would otherwise set using the options.
EOHELP
  _help_environment_var
  exit 1;
}


_build_deps_cmd() {
  _build_array_cmd "${PPKG_DEPENDENCIES}" "--depends"
}

_build_excludes_cmd() {
  set -f
  _build_array_cmd "${PPKG_EXCLUDES}" "--exclude"
  set +f
}

_build_configs_cmd() {
  _build_array_cmd "${PPKG_CONFIGS}" "--config-files"
}
_build_provides_cmd() {
  _build_array_cmd "${PPKG_PROVIDES}" "--provides"
}

_build_array_cmd() {
  local cmd
  local item
  local arr="${1// /…}"
  local opt="$2"
  for item in $( echo "${arr}" | tr ',' "\n" ); do
    cmd="${cmd} ${opt} '${item//…/ }'";
  done;
  echo "$cmd";
}

_map_branch_to_environment() {
  local branch=$1
  for map in $PPKG_MAP_ENVIRONMENTS; do
    if echo $map | grep -q "^${branch}="; then
      echo "${map##${branch}=}"
      debug "ROUND REMAP: branch '${branch}' -> '${map##${branch}=}'"
      return 0;
    fi
  done;
  echo $branch
  return 0;
}

## getopts parsing
if `getopt -T >/dev/null 2>&1` ; [ $? = 4 ] ; then
  true; # Enhanced getopt.
else
  err "You are using an old getopt version $(getopt -V)";
  exit 1;
fi;


TEMP=`getopt -o -e:v:i:t:h \
  -l environment:,version:,iteration:,type:,help -n "$0" -- "$@"`;

if [[ $? != 0 ]]; then
  err "Error parsing arguments";
  exit 1;
fi;

while [ $# -gt 0 ]; do
  case "$1" in
    -e|--environment)     PPKG_ENVIRONMENT="$2"; shift;;
    -v|--version)         PPKG_VERSION="$2"; shift;;
    -i|--iteration)       PPKG_ITERATION="$2"; shift;;
    -t|--type)            PPKG_TYPE="$2"; shift;;
    -h|--help)            _help;;
    -*)                   err "Command option '$1' not recognized"; exit 1;;
    --)                   shift; break;;
    *)                    break;;
  esac;
  shift;
done;


## No arguments
if [[ ${#*} == 0 && ! "${PPKG_TARGET}" ]]; then
  echo "ERROR: No arguments provided. You should specify the folder to package or set the PPKG_TARGET environment variable";
  echo ""
  _help;
fi;

##---- TARGET FOLDER -----##
PPKG_TARGET="${PPKG_TARGET-${1}}";
if [ ! -d "$PPKG_TARGET" ]; then
  err "TARGET is not a folder (${PPKG_TARGET})!"
  exit 1;
fi;

[ -f "${PPKG_TARGET}/.ppkg-settings" ] && \
  source "${PPKG_TARGET}/.ppkg-settings"

if [ "$PPKG_MIN_VERSION" ]; then
  if [ $PPKG_MIN_VERSION == $VERSION ]; then
    debug "Required version is current version.";
  else
    _vspec=$( echo -e $PPKG_MIN_VERSION"\n"$VERSION | sort -t'.' -g | tail -n 1)
    if [ "$_vspec" == "${PPKG_MIN_VERSION}" ]; then
      err "You requested a minimum script version '${PPKG_MIN_VERSION}' but current version is '${VERSION}'."
      exit 1;
    else
      debug "Required version is newer.";
    fi;
  fi;

fi;

if echo "$PPKG_NO_RELEASE" | grep -q "false\|0\|no"; then
  PPKG_NO_RELEASE=""
fi;

debug "PPKG_TARGET: '${PPKG_TARGET}'";

PPKG_DEFAULT_VERSION="${PPKG_DEFAULT_VERSION-1.0}"

##----- GIT RELATED SETTINGS -----##
PPKG_GIT_RELEASE_BRANCH="${PPKG_GIT_RELEASE_BRANCH-master}";
debug "PPKG_GIT_RELEASE_BRANCH: '${PPKG_GIT_RELEASE_BRANCH}'";

# The git root (work-tree) defaults to the provided target directory
PPKG_GIT_ROOT="${PPKG_GIT_ROOT-${PPKG_TARGET}}";
debug "PPKG_GIT_ROOT: '${PPKG_GIT_ROOT}'";

_GIT_DIR=$( get_git_dir $PPKG_GIT_ROOT ) || warn "could not find the git dir"
debug "_GIT_DIR: '${_GIT_DIR}'"

if [ "$_GIT_DIR" ]; then
  _GIT_TAG=`get_tag $PPKG_GIT_ROOT` || warn "could not find a git tag"

  ## Expanded branch logic. We ran into a problem when we are in a
  # detached state and the commit was in several branches.


  _GIT_BRANCHES=`get_all_branches $PPKG_GIT_ROOT | grep "remotes/*" | grep -o '[^/]\+$'`;
  # we are forcing the use of this branch. Can we?
  if [ "$PPKG_GIT_FORCE_BRANCH" ]; then
    debug "Enforcing git branch: '${PPKG_GIT_FORCE_BRANCH}'";
    if echo "${_GIT_BRANCHES}" | grep -q "${PPKG_GIT_FORCE_BRANCH}"; then
      _GIT_BRANCHES="${PPKG_GIT_FORCE_BRANCH}";
    else
      err "Forcing the use of branch '${PPKG_GIT_FORCE_BRANCH}' but this branch does not have the current commit."
      exit 1;
    fi
  else
    # Are we enforcing NO_RELEASE or there is no tag? get rid of the release branch and recheck the branch list.
    if [[ "${PPKG_NO_RELEASE}" || ! "${_GIT_TAG}" ]]; then
      _GIT_BRANCHES=`echo "${_GIT_BRANCHES}" | grep -v "${PPKG_GIT_RELEASE_BRANCH}"`
      debug "PPKG_NO_RELEASE set ('${NO_RELEASE}') or no GIT TAG found: removed the git release branch ('${PPKG_GIT_RELEASE_BRANCH}')";
    fi;
    # Are we NOT enforcing NO_RELEASE? Is there a tag on the release branch? if yes, use it, if not, remove it.
    if [[ "${_GIT_TAG}" && $(echo "${_GIT_BRANCHES}" | grep -q "${PPKG_GIT_RELEASE_BRANCH}" ) ]]; then
      _GIT_BRANCHES="${PPKG_GIT_RELEASE_BRANCH}";
      debug "Tag found on the release branch ('${PPKG_GIT_RELEASE_BRANCH}')";
    fi
    # Are there multiple something elses? Pick one and warn about it.
  fi;

  debug "_GIT_BRANCHES: '${_GIT_BRANCHES}'";
  if [ `echo "${_GIT_BRANCHES}" | wc -l` == 1 ]; then
    # there is only one branch, use that!
    _GIT_BRANCH="${_GIT_BRANCHES}";
  else
    warn "Multiple branches contain this commit! Defaulting to the first one";
    _GIT_BRANCH="`echo "${_GIT_BRANCHES}" | head -n1`";
  fi;
fi;
debug "_GIT_TAG: '${_GIT_TAG}'";
debug "_GIT_BRANCH: '${_GIT_BRANCH}'";

##----- PACKAGE ENVIRONMENT -----##
# environment has been specified.
if [[ "${PPKG_ENVIRONMENT}" && "${PPKG_ENVIRONMENT}" != "GIT_BRANCH" ]]; then
  debug "Environment has been specified"
# do we have a branch?
elif [ "${_GIT_BRANCH}" ]; then
  # is it the release branch?
  if [ "${PPKG_MAP_ENVIRONMENTS}" ]; then
    PPKG_ENVIRONMENT=`_map_branch_to_environment $_GIT_BRANCH`;
  elif [ "${_GIT_BRANCH}" == "${PPKG_GIT_RELEASE_BRANCH}" ]; then
    # do we have a git tag?
    if [ "${_GIT_TAG}" ]; then
      # use it
      PPKG_ENVIRONMENT="${_GIT_TAG}";
    else
      # warn there is no tag and use the branch name.
      warn "We are on the release branch but no tag has been set!"
      PPKG_ENVIRONMENT="${_GIT_BRANCH}";
    fi
  else
    if [[ "${GIT_TAG}" && "${PPKG_ENVIRONMENT}" != "GIT_BRANCH" ]]; then
      PPKG_ENVIRONMENT="${_GIT_BRANCH}-${_GIT_TAG}"
    else
      PPKG_ENVIRONMENT="${_GIT_BRANCH}";
    fi
  fi
else
  # errrr dno what to do now!
  PPKG_ENVIRONMENT="";
  err "No git branch detected. You should provide the environment name using the options or the PPKG_ENVIRONMENT variable"
  exit 1;
fi
debug "PPKG_ENVIRONMENT: '${PPKG_ENVIRONMENT}'";

##----- PACKAGE PREFIX -----##
PPKG_PREFIX="${PPKG_PREFIX-/etc/puppet/environments/${PPKG_ENVIRONMENT}}";
debug "PPKG_PREFIX: '${PPKG_PREFIX}'";

##----- PACKAGE NAME -----##
PPKG_NAME_PREFIX="${PPKG_NAME_PREFIX}"
debug "PPKG_NAME_PREFIX: '${PPKG_NAME_PREFIX}'";

PPKG_NAME_BASE="${PPKG_NAME_BASE-puppet-tree}"
debug "PPKG_NAME_BASE: '${PPKG_NAME_BASE}'"

if [[ ! "${PPKG_NAME}" && "${PPKG_NAME_PREFIX}" ]]; then
  PPKG_NAME="${PPKG_NAME_PREFIX}-${PPKG_NAME_BASE}-${PPKG_ENVIRONMENT}";
fi
PPKG_NAME="${PPKG_NAME-${PPKG_NAME_BASE}-${PPKG_ENVIRONMENT}}";
debug "PPKG_NAME: '${PPKG_NAME}'";

##----- PACKAGE VERSION -----##
if [ "${PPKG_VERSION}" == "GIT_TAG" ]; then
  PPKG_VERSION="${PPKG_DEFAULT_VERSION}"
  if [ "${_GIT_TAG}" ]; then
    PPKG_VERSION="${_GIT_TAG}";
  else
    warn "requested to use the git tag as version but could not find a tag. falling back to default."
  fi;
fi;
PPKG_VERSION="${PPKG_VERSION-${PPKG_DEFAULT_VERSION}}";
debug "PPKG_VERSION: '${PPKG_VERSION}'";

##----- PACKAGE ITERATION -----##
#use jenkins stuff if available for the default value.
_PPKG_DEFAULT_ITERATION="${BUILD_NUMBER-0}"
PPKG_ITERATION="${PPKG_ITERATION-${_PPKG_DEFAULT_ITERATION}}";
debug "PPKG_ITERATION: '${PPKG_ITERATION}'";

##----- PACKAGE TYPE -----##
PPKG_TYPE="${PPKG_TYPE-rpm}";
debug "PPKG_TYPE: '${PPKG_TYPE}'";

##----- GENERAL PACKAGE STUFFS -----##
PPKG_VENDOR="${PPKG_VENDOR}";
PPKG_DESCRIPTION="${PPKG_DESCRIPTION}";
PPKG_CATEGORY="${PPKG_CATEGORY}";
PPKG_MAINTAINER="${PPKG_MAINTAINER}";
PPKG_URL="${PPKG_URL}";

##----- DEPENDENCIES -----##
PPKG_DEPENDENCIES="${PPKG_DEPENDENCIES-puppet}"; #handled
PPKG_CONFIGS="${PPKG_CONFIGS}";
PPKG_EXCLUDES="${PPKG_EXCLUDES-**/.git*}";
PPKG_PROVIDES="${PPKG_PROVIDES}";


#==========================================================
# |              o          |
# |    ,---.,---..,---.,---.|
# |    |   ||   |||    ,---||
# `---'`---'`---|``---'`---^`---'
#           `---'


## Building the command line for fpm.

_ppkg_cmd="fpm -t ${PPKG_TYPE} -s dir -a all -n ${PPKG_NAME}";
_ppkg_cmd="$_ppkg_cmd -v ${PPKG_VERSION} --epoch=1 --iteration ${PPKG_ITERATION}";
[ "${PPKG_DESCRIPTION}" ] && \
  _ppkg_cmd="$_ppkg_cmd --description '${PPKG_DESCRIPTION}'";
[ "${PPKG_URL}" ] && _ppkg_cmd="$_ppkg_cmd --url '${PPKG_URL}'";
[ "${PPKG_CATEGORY}" ] && _ppkg_cmd="$_ppkg_cmd --category '${PPKG_CATEGORY}'";
[ "${PPKG_VENDOR}" ] && _ppkg_cmd="$_ppkg_cmd --vendor '${PPKG_VENDOR}'";
[ "${PPKG_MAINTAINER}" ] && _ppkg_cmd="$_ppkg_cmd -m '${PPKG_MAINTAINER}'";

_ppkg_cmd="$_ppkg_cmd --prefix ${PPKG_PREFIX}";
_ppkg_cmd="$_ppkg_cmd `_build_deps_cmd`";
_ppkg_cmd="$_ppkg_cmd `_build_configs_cmd`";
_ppkg_cmd="$_ppkg_cmd `_build_excludes_cmd`";
[ -f "${PPKG_TARGET}/.ppkg-settings" ] && _ppkg_cmd="$_ppkg_cmd -x '**/.ppkg-settings'";
_ppkg_cmd="$_ppkg_cmd `_build_provides_cmd`";

_ppkg_cmd="$_ppkg_cmd -C ${PPKG_TARGET} .";

debug "PPKG_CMD: $_ppkg_cmd";

[ "${SCRIPTDEBUG}" ] && exit 0;

eval $_ppkg_cmd;

