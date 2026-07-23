#!/bin/sh
set -eu
dir=$(realpath -e -- "${PACKAGE_DIR:?explicit PACKAGE_DIR required}")
rm -f -- "$dir/task7lcalibration.exe" \
  "$dir/.hol/objs/task7lcalibration.ui" \
  "$dir/.hol/objs/task7lcalibration.uo" \
  "$dir/.hol/locks/task7lcalibration.exe.lock" \
  "$dir/.hol/locks/task7lcalibration.uo.lock" \
  "$dir/.hol/make-deps/task7lcalibration.sml.d"
find "$dir/.hol" -depth -type d -empty -delete 2>/dev/null || true
for path in task7lcalibration.exe .hol/objs/task7lcalibration.ui \
  .hol/objs/task7lcalibration.uo .hol/locks/task7lcalibration.exe.lock \
  .hol/locks/task7lcalibration.uo.lock \
  .hol/make-deps/task7lcalibration.sml.d; do
  test ! -e "$dir/$path"
done
echo 'live generated artifact and metadata cleanup: PASS'
