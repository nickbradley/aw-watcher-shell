# aw-watcher-shell

A BASH and ZSH command tracker for [ActivityWatch](https://activitywatch.net/) based on Carl Anderson's [Advanced Shell History](https://github.com/barabo/advanced-shell-history) project.
Records the command, duration, working directory, and exit code.

## Install
1. Download the latest release and unzip.
2. Source aw-watcher-shell in `~/.bashrc` and/or `~/.zshrc`.

To confirm that aw-watcher-shell has been correctly sourced, open a new shell.
You should see `aw-watcher shell v1.0.0` displayed before the first prompt is drawn.

## Uninstall

Note: if you just want to disable data collection, you can pause the ActivityWatch server.

Unsource aw-watcher-shell in `~/.bashrc` and/or `~/.zshrc` and restart your shell.