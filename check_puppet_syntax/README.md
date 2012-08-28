# NOTES

Currently we are not using --ignoreimport when running `puppet parser validate`.
This results in some errors being printed twice. This will remain this way until
https://projects.puppetlabs.com/issues/9670 is resolved.
