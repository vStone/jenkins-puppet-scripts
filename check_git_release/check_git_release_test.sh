#!/bin/bash

green=$( tput setaf 2 );
bgreen=$( tput setaf 2; tput bold );
red=$( tput setaf 1 );
bred=$( tput setaf 1; tput bold );
reset=$( tput sgr0 );

ok() {
  local test="$1";
  pos=$(( $(tput cols) - `echo "$test" | wc -c` - 8 ));
  if [ $pos -gt 5 ]; then
    echo "${test} $(tput cuf $pos )[${bgreen}PASSED${reset}]";
  else
    echo "${test} [${bgreen}PASSED${reset}]";
  fi;
}
nok() {
  local test="$1";
  local err="${2-no reason provided}";
  local msg="$test [$err]";
  pos=$(( $(tput cols) - `echo "$msg" | wc -c` - 8 ));
  if [ $pos -gt 5 ]; then
    echo "${msg} $(tput cuf $pos )[${bred}FAILED${reset}]";
  else
    echo "${msg} [${bred}FAILED${reset}]";
  fi;
}

create_repo() {
  local d=$1;
  rm -rf $d;
  mkdir -p $d;
  (cd $d; git init 1>/dev/null; touch README; git add README 1>/dev/null; git commit -m 'Initial commit' 1>/dev/null);
}

create_file() {
  local d=$1;
  local f=$2;
  local m="${3}";
  local c="${4}"
  (cd $d; echo "$c" > $f;  git add $f 1>/dev/null; git commit -m "$m" 1>/dev/null);
}

tag() {
  local d=$1;
  local t=$2;
  (cd $d; git tag $t 1>/dev/null);
}

add_submod() {
  local d=$1;
  local s=../$2;
  (cd $d; git submodule add $s $2 1>/dev/null; git commit -m "Added subrepo $2" 1>/dev/null);
}



test_should_be() {
  local test="$1";
  local command="$2";
  local regex="$3";
  echo $command
  if [ "$4" ]; then
    eval "$command 2>&1" >/dev/null;
    exit=$?
    if [ $exit != $4 ]; then
      nok "$test" "wrong exit status. expected $4, got $exit"; return 1;
    fi;
  fi;

  if eval "$command 2>&1" | grep -qz --color=always "$regex"; then
    ok "$test";
  else
    nok "$test" "output '$regex' does not match"; return 1;
  fi;
}

echo "Preparing test environment"

echo "+ creating test_subrepo_tag"
create_repo test_subrepo_tag
create_file test_subrepo_tag VERSION "Version bump to 0.1" "Version 0.1";
tag test_subrepo_tag "0_1"

echo "+ create test_subrepo_notag"
create_repo test_subrepo_notag

echo "+ create test_subrepo_dirty"
create_repo test_subrepo_dirty
tag test_subrepo_dirty "0_1"
touch test_subrepo_dirty/dirty

echo "+ creating test_repo";
create_repo test_repo
create_file test_repo VERSION "Version bump to 0.1" "Version 0.1"
echo "++ adding subrepo test_subrepo_notag";
add_submod test_repo test_subrepo_notag
echo "++ adding subrepo test_subrepo_dirty";
add_submod test_repo test_subrepo_dirty
echo "++ adding subrepo test_subrepo_tag";
add_submod test_repo test_subrepo_tag
tag test_repo "0_1"

echo "+ creating test_repo_dots"
create_repo test_repo_dots
create_file test_repo_dots VERSION "Version bump to 0.1" "Version 0.1";
tag test_repo_dots "0.1"

echo '#                     o              |              |'
echo '# ,---..   .,---.,---..,---.,---.    |--- ,---.,---.|--- ,---.';
echo "# |    |   ||   ||   |||   ||   |    |    |---'\`---.|    \`---.";
echo "# \`    \`---'\`   '\`   '\`\`   '\`---|    \`---'\`---'\`---'\`---'\`---'"
echo "#                           \`---'"


#./check_git_release.sh test_repo 2>&1 >/dev/null
#exit_should_be "single repository, no tag set" 1 $?



test_should_be "single repository, no tag set [no args]" \
  "./check_git_release.sh test_subrepo_notag" \
  "GIT_CHECK:ERROR:MAIN:SYS:could not find any tag on path"

x="$?"

test_should_be "single repository, tag set [no args]" \
  "./check_git_release.sh test_subrepo_tag" \
  "GIT_CHECK:INFO:MAIN:TAG="
e=$?

[ "$x" == "0" ] && x="$e"

test_should_be "single repository, bogus tag set [no args]" \
  "./check_git_release.sh test_repo_dots" \
  "GIT_CHECK:ERROR:MAIN:SYS:tag contains invalid" 1
e=$?

[ "$x" == "0" ] && x="$e"

test_should_be "single repository, bogus tag set [--no-tag-check]" \
  "./check_git_release.sh --no-tag-check test_repo_dots" \
  "GIT_CHECK:INFO:MAIN:TAG=" 0
e=$?

[ "$x" == "0" ] && x="$e"

test_should_be "single_repository, dirty [no args]" \
  "./check_git_release.sh test_subrepo_dirty" \
  "GIT_CHECK:ERROR:MAIN:SYS:the git tree seems to be dirty" 1
e=$?

[ "$x" == "0" ] && x="$e"

test_should_be "single_repository, dirty [--dirty-tree-error 0]" \
  "./check_git_release.sh --dirty-tree-error 0 test_subrepo_dirty " \
  "GIT_CHECK:WARN:MAIN:SYS:the git tree seems to be dirty" 0
e=$?

[ "$x" == "0" ] && x="$e"

test_should_be "repo with submodules, tag set [no args]" \
  "./check_git_release.sh test_repo" \
  "GIT_CHECK:INFO:MAIN:TAG=" 0
e=$?

[ "$x" == "0" ] && x="$e"

test_should_be "repo with submodules, tag set [--submods-tag-error 1]" \
  "./check_git_release.sh --submods-tag-error 1 test_repo" \
  "GIT_CHECK:INFO:MAIN:TAG=" 1
e=$?

[ "$x" == "0" ] && x="$e"

touch test_repo/test_subrepo_dirty/dirty
test_should_be "repo with submodules, dirty submodule [no args]" \
  "./check_git_release.sh test_repo" \
  "GIT_CHECK:ERROR:MAIN:SYS:the git tree seems to be dirty.*GIT_CHECK:ERROR:SUBMODULE:test_subrepo_dirty:SYS:the git submodule tree seems to be dirty" 1
e=$?

[ "$x" == "0" ] && x="$e"

test_should_be "repo with submodules, dirty submodule [--dirty-tree-error 0]" \
  "./check_git_release.sh --dirty-tree-error 0 test_repo" \
  "GIT_CHECK:WARN:MAIN:SYS:the git tree seems to be dirty.*GIT_CHECK:WARN:SUBMODULE:test_subrepo_dirty:SYS:the git submodule tree seems to be dirty" 0
e=$?

[ "$x" == "0" ] && x="$e"

if [ $x == "1" ]; then
  echo "ERRORS found. Skipping cleanup"
else
  echo "Cleaning up"
  rm -rf test_repo* test_subrepo*
fi;
exit $x;
