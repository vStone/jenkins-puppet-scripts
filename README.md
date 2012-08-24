# Introduction

This repo contains various scripts that get used throughout our Jenkins setup.

# Usage

A recommended way of using these scripts could be to setup a separate Jenkins
job that pull in this repository.

Define each script as a managed script and add the arguments. See the README or
script itself to find out what arguments are available.

# Jenkins

Below follows a quick overview on how these scripts are used on our Jenkins
instance. You can either use the script directly or used it through the config
file provider plugin (see below). Both should be pretty straightforward.
We use parameters extensively.

## Used plugins

The following plugins (and their dependencies) are used for setting up the jobs.

* [Downstream Build View Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Downstream+buildview+plugin):
  Optional plugin to display your build pipelines.
* [Config File Provider Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Config+File+Provider+Plugin):
  Manage your often used scripts in a centralized fashion.
* [Warnings Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Warnings+Plugin):
  This plugin generates the trend report for compiler warnings in the console
  log or in log files. The warnings plugin has support for puppet-lint.
* [Parameterized Trigger Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Parameterized+Trigger+Plugins):
  Triggers parametrized builds on other jobs.
  [GIT Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin):
  This plugin integrates GIT with Jenkins.
* [GIT Parameter Plugin](https://github.com/lukanus/git-parameter):
  Adds ability to choose from git repository revisions or tags.

## Pipelines

We use 2 almost similar pipelines. One for release branch and one for development
branches. The packaging system uses this information to build 2 kind of packages.
In short: The release branch needs a tag. The tag will be used as the environment.
For development branches. the development name is used as the environment. If a tag
is set on such a branch, we will append it to the environment name.

### 1. Release Pipeline [puppet-tree-release]

Holds ALL the parameters that can influence a build. We use this as a single entry point
for our pipeline. You really don't want to start any build except the entry build.

This has a couple of advantages. It will catch problems with your VCS. GIT in our case.
If you git submodules, somebody will forget to push the submodule before the parent tree
and your job will get stuck in a fail loop. We would not want these kind of hiccups to
mess up the build trend for various more important checks.

This job will trigger the next one if everything goes fine.

### 2. Syntax Checks [puppet-tree-release-syntax]

Do syntax checks on as much code as possible. Currently, we have ruby templates and
puppet manifests covered.

### 0. Add your fantastic spec test script here!

### 3. Style Checks [puppet-tree-release-style]

The tagging check would be a lot faster to do here, but it might be interesting to already
get a picture of the errors on the master branch. :)

### 4. GIT Tagging check [puppet-tree-release-tagging]

Check if a tag is set. We need to enforce this because otherwise people push stuff into
production like savages. We need to get rid of that mentality. If you broke something,
create a hotfix with proper tagging etc etc.

### 5. Packaging [puppet-tree-release-packaging]
Package it. We use fpm to produce RPMs. Easily adjustable to produce debs or ...

### 6. Deploy it [puppet-tree-release-deploy]
Either push it to a pulp repo, or scp it to some site or ...


# TODO:

What we still need is

* A job for documentation. I have some stuff somewhere.
* A job for spec tests. Preferably, also a Jenkins warnings parser addition to parse the output.
* While we are talking about Jenkins warnings parser: We need to support having modules in different
  structures than just /modules/ALLTHESTUFF.

