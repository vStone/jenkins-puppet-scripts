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

## Jobs


