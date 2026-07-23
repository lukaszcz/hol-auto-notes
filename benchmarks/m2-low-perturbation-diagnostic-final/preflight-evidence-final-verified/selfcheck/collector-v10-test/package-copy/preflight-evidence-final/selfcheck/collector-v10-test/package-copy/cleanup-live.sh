#!/bin/sh
set -eu
dir=$(realpath -e -- "${PACKAGE_DIR:?explicit PACKAGE_DIR required}")
rm -f -- "$dir/task7nclock.exe" \
  "$dir/.hol/objs/task7nclock.ui" \
  "$dir/.hol/objs/task7nclock.uo" \
  "$dir/.hol/locks/task7nclock.exe.lock" \
  "$dir/.hol/locks/task7nclock.uo.lock" \
  "$dir/.hol/make-deps/task7nclock.sml.d"
find "$dir/.hol" -type f -path '*/logs/*' -delete 2>/dev/null || true
find "$dir/.hol" -depth -type d -empty -delete 2>/dev/null || true
for path in task7nclock.exe .hol/objs/task7nclock.ui \
  .hol/objs/task7nclock.uo .hol/locks/task7nclock.exe.lock \
  .hol/locks/task7nclock.uo.lock .hol/make-deps/task7nclock.sml.d; do
  test ! -e "$dir/$path"
done
echo 'live exe/UI/UO/lock/dependency/log cleanup: PASS'

