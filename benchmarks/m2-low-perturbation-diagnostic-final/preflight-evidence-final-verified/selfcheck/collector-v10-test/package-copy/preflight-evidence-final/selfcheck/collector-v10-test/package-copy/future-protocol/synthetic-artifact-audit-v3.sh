#!/bin/sh
set -eu
output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root|--package-dir|--scratch-root|--scratch-dir)
      [ "$#" -ge 2 ] || exit 2
      shift 2
      ;;
    --output)
      [ "$#" -ge 2 ] || exit 2
      output=$2
      shift 2
      ;;
    *) exit 2 ;;
  esac
done
[ -n "$output" ] || exit 2
cp "${SYNTHETIC_ARTIFACT_SOURCE:?source required}" "$output"
