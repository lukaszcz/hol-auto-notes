#!/bin/sh
set -eu
dir=$(realpath -e -- "${PACKAGE_DIR:?explicit PACKAGE_DIR required}")
rm -f -- "$dir/task7mcalibration.exe" \
  "$dir/.hol/objs/task7mcalibration.ui" \
  "$dir/.hol/objs/task7mcalibration.uo" \
  "$dir/.hol/locks/task7mcalibration.exe.lock" \
  "$dir/.hol/locks/task7mcalibration.uo.lock" \
  "$dir/.hol/make-deps/task7mcalibration.sml.d"
find "$dir/.hol" -type f -path '*/logs/*' -delete 2>/dev/null || true
find "$dir/.hol" -depth -type d -empty -delete 2>/dev/null || true
for path in task7mcalibration.exe .hol/objs/task7mcalibration.ui \
  .hol/objs/task7mcalibration.uo .hol/locks/task7mcalibration.exe.lock \
  .hol/locks/task7mcalibration.uo.lock \
  .hol/make-deps/task7mcalibration.sml.d; do
  test ! -e "$dir/$path"
done
echo 'live exe/UI/UO/lock/dependency/log cleanup: PASS'
