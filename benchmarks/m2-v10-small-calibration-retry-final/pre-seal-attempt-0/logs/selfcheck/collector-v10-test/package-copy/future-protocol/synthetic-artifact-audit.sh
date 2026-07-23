#!/bin/sh
set -eu
out=${1:?output required}
cp "${SYNTHETIC_ARTIFACT_SOURCE:?source required}" "$out"
