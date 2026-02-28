#!/usr/bin/env bash
# Cross-platform host initialization for devcontainer
# Runs on macOS, Linux, and Windows (Git Bash / WSL)
set -e

# Resolve home directory (HOME on macOS/Linux, USERPROFILE on Windows)
USER_HOME="${HOME:-$USERPROFILE}"

if [ -z "$USER_HOME" ]; then
  echo "ERROR: Cannot determine home directory (neither HOME nor USERPROFILE is set)" >&2
  exit 1
fi

mkdir -p "$USER_HOME/.kube" \
         "$USER_HOME/.aws" \
         "$USER_HOME/Documents/Projects"

# Create zsh history file if it doesn't exist
[ -f "$USER_HOME/.zsh_history_devcontainers" ] || touch "$USER_HOME/.zsh_history_devcontainers"
