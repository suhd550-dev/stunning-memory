#!/bin/bash

WORKSPACE_DB="/workspace/sessions.db"
HOME_DB="$HOME/.local/share/opencode/sessions.db"

mkdir -p "$(dirname "$HOME_DB")"

# Pull from home to workspace
if [ -f "$HOME_DB" ]; then
  cp "$HOME_DB" "$WORKSPACE_DB"
  echo "Pulled $HOME_DB -> $WORKSPACE_DB"
else
  echo "Skip pull: $HOME_DB not found"
fi

# Push from workspace to home
if [ -f "$WORKSPACE_DB" ]; then
  cp "$WORKSPACE_DB" "$HOME_DB"
  echo "Pushed $WORKSPACE_DB -> $HOME_DB"
else
  echo "Skip push: $WORKSPACE_DB not found"
fi
