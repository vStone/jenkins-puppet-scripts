#!/bin/bash
#
# Script wich catches the modified files from the latest commit in a git repository and
# runs a puppet-lint check on them
#
# Variables to be set:
#
# PUPPET_SUBDIR
#
# PUPPET_LINT_THREADS, PUPPET_LINT_SKIP_TESTS, PUPPET_LINT_SKIP_EXAMPLES,
# PUPPET_LINT_BIN, PUPPET_LINT_FAILS_WARNING, PUPPET_LINT_FAILS_ERROR
#
# CHANGED_FILES: you can pass the list of files which have to be checked

GIT_PREVIOUS_COMMIT="${GIT_PREVIOUS_COMMIT-HEAD^}"

[ "$EXTRA_PATH" ] && export PATH="$EXTRA_PATH:$PATH";

# you can pass changed files in the variable/parameter CHANGED_FILES
[ -z "$CHANGED_FILES" ] && CHANGED_FILES=$(git diff --name-only --diff-filter=ACMRTUXB HEAD ${GIT_PREVIOUS_COMMIT})

printenv | sort

manifests_exclude="${1-autoloader_layout}"
module_exclude="${2}"
style_script="$(cd $(dirname "$0"); pwd)/../check_puppet_style/check_puppet_style.sh"

# Catch the modified .pp manifests, puts them in an array and use that array to peform the puppet-style checks
declare -a files

for FILE in $(echo $CHANGED_FILES | tr ' ' '\n' | grep ".pp$");
do
	files=("${files[@]}" $FILE)
done

if [ ${#files[@]} -eq 0 ];then
	echo "No modified manifests to check"
else
	for i in ${files[@]};
	do
	  echo "Stylecheck on manifest $i:";
		bash -e "${style_script}" -x "${manifests_exclude}" $i || manifests_failed=1
	done
fi

# Catch the modified modules, puts them in an array and use that array to peform the puppet-style checks
declare -a modules

for MODULE in $(echo $CHANGED_FILES | tr ' ' '\n' | grep "^modules/");
do
	modules=("${modules[@]}" $MODULE)
done

if [ ${#modules[@]} -eq 0 ];then
	echo "No modified modules to check"
else
	for i in ${modules[@]};
	do
    echo "Stylecheck on module $i:";
		bash -e "${style_script}" -x "${module_exclude}" $i || module_failed=1
	done
fi

failed=0
if [ "$manifests_failed" == "1" ]; then
  echo "Style check on manifests dir failed";
  failed=1;
fi
if [ "$module_failed" == "1" ]; then
  echo "Style check on modules failed";
  failed=1;
fi;

[ "$failed" == "0" ] || exit 1;
