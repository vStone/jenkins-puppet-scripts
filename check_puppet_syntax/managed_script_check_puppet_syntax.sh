#!/bin/bash
#
# Runs a syntax check on the modified files of a puppet tree only
# Variables to be set: PUPPET_SYNTAX_THREADS, PUPPET_BIN, ERB_BIN, RUBY_BIN
#
# scripts_job_name: Name of the jenkins job which is used to pull this repo into your jenkins environment

[ -z $GIT_PREVIOUS_COMMIT ] && GIT_PREVIOUS_COMMIT='HEAD^'

[ "$EXTRA_PATH" ] && export PATH="$EXTRA_PATH:$PATH";
scripts_job_name="scripts/puppet"

# Catch the modified .pp manifests, puts them in an array and use that array to peform the puppet-syntax checks
declare -a files

for FILE in $(git diff --name-only --diff-filter=ACMRTUXB ${GIT_PREVIOUS_COMMIT} | grep ".pp$");
do
	files=("${files[@]}" $FILE)
done

if [ ${#files[@]} -eq 0 ];then
        echo "No modified manifests to check"
else
        for i in ${files[@]};
        do
                echo "Syntax check on manifest $i:";
		bash -e /var/lib/jenkins/$scripts_job_name/check_puppet_syntax/check_puppet_syntax.sh $i || manifests_failed=1
        done
fi

# Catch the modified modules, puts them in an array and use that array to peform the puppet-style checks
declare -a modules

for MODULE in $(git diff --name-only --diff-filter=ACMRTUXB ${GIT_PREVIOUS_COMMIT} | grep "^modules/");
do
	modules=("${modules[@]}" $MODULE)
done

if [ ${#modules[@]} -eq 0 ];then
        echo "No modified modules to check"
else
        for i in ${modules[@]};
        do
                echo "Syntax check on module $i:";
		bash -e /var/lib/jenkins/$scripts_job_name/check_puppet_syntax/check_puppet_syntax.sh $i || module_failed=1
        done
fi


failed=0
if [ "$manifests_failed" == "1" ]; then
  echo "Syntax check on manifests dir failed";
  failed=1;
fi
if [ "$module_failed" == "1" ]; then
  echo "Syntax check on modules failed";
  failed=1;
fi;

[ "$failed" == "0" ] || exit 1;
