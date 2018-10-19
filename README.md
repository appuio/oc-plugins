oc-plugins
==========

A collection of plugins for the OKD / Kubernetes CLI client.

1. `cleanup`: Clean up excessive (stale) resources

Usage
-----

```bash
oc plugin <plugin-name>
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

1. Bash
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
