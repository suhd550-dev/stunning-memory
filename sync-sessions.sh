#!/bin/bash

SRC="$HOME/.local/share/opencode/opencode.db"
DST="/workspace/opencode.db"

if [ ! -f "$SRC" ]; then
  echo "Error: $SRC not found" >&2
  exit 1
fi

cp "$SRC" "$DST"
echo "Copied $SRC -> $DST"
