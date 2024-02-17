# GitLab Custom runner for Incus

This is the [updated custom LXD GitLab runner][0] to run with
the LXD fork [Incus][1].

## Setup

Checkout my [blog post][2].

## Runner Configuration

This assumes that incus is installed!

```
[[runners]]
  name = "incus-driver"
  token = "xxxxxxxxxxx"
  executor = "custom"
  builds_dir = "/builds"
  cache_dir = "/cache"
  [runners.custom]
    prepare_exec = "/opt/incus-driver/prepare.sh" # Path to a bash script to create incus container and download dependencies.
    run_exec = "/opt/incus-driver/run.sh" # Path to a bash script to run script inside the container.
    cleanup_exec = "/opt/incus-driver/cleanup.sh" # Path to bash script to delete container.

```

[0]: https://docs.gitlab.com/runner/executors/custom_examples/lxd.html
[1]: https://linuxcontainers.org/incus/
[2]: https://l33tsource.com/blog/2024/02/17/Incus-GitLab-runner/
