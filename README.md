oc-plugins
==========

[![Travis CI](https://travis-ci.com/appuio/oc-plugins.svg?branch=master)](https://travis-ci.com/appuio/oc-plugins)
[![container-oc Build](https://img.shields.io/docker/build/appuio/oc.svg)](https://hub.docker.com/r/appuio/oc/builds)

A collection of plugins for the OKD / Kubernetes CLI client.

1. `cleanup`: Clean up excessive (stale) resources

Usage
-----

```console
oc plugin <plugin-name> --help
```

### cleanup

Cleanup removes stale image stream tags that are tagged with a commit SHA of
a specific repository (e.g. when you automatically tag built images with the
related Git commit hash). [Due to a bug](https://github.com/kubernetes/kubernetes/issues/55708)
you have to explicitly specify the local Git repository with an absolute path.

```bash
oc plugin cleanup my-image -p /path/to/git-repository/
```

Example: (using Docker)

```console
$ docker run --rm -it -v $(pwd):/app appuio/oc:v3.9 oc plugin cleanup --help
Clean up excessive (stale) image tags, images and related resources.

Usage:
  oc plugin cleanup [options]

Examples:
  oc plugin cleanup IMAGE --git-repo-path $PWD

Options:
  -f, --force='n': don't ask for confirmation to delete image tags (use: y)
  -l, --git-commit-limit='100': only look at the first <n> commits to compare with tags
  -p, --git-repo-path='': absolute path to Git repository (for current dir use: $PWD)
  -k, --keep='10': keep most current <n> images

Use "oc options" for a list of global command-line options (applies to all commands).
```

Installation
------------

See [Installing Plug-ins](
https://docs.openshift.com/container-platform/3.9/cli_reference/extend_cli.html#cli-installing-plugins
) in the official documentation.

Prerequisites
-------------

The image or infrastructure using this plugin collection must meet the
following requirements for the commands to work.

### cleanup

1. Bash v4+
1. Git

Development
-----------

- [Extending the CLI](https://docs.openshift.com/container-platform/3.9/cli_reference/extend_cli.html)
  (official docs)

```bash
# configure plugins path for development
export KUBECTL_PLUGINS_PATH=$(pwd)

# list all plugins, print usage
oc plugin
```
