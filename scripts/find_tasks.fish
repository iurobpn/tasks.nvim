#!/usr/bin/env fish
set SCRIPT_DIR (realpath (dirname (status --current-filename)))
find_tasks $argv
