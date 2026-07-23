#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
exec python3 -B "$dir/audit-runtime.py" "$@"
