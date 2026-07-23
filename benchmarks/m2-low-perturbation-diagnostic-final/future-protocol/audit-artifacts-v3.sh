#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
exec python3 "$dir/audit-artifacts-v3.py" "$@"
