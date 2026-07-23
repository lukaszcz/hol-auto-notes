#!/bin/sh
set -eu

scratch_root=${1:?caller-provided scratch root required}
scratch_dir=${2:?caller-provided scratch directory required}

die() {
  echo "scratch path validation: $*" >&2
  exit 2
}

absolute_spelling() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$(pwd -P)" "$1" ;;
  esac
}

normalize_trailing_slashes() {
  path=$1
  while [ "$path" != / ] && [ "${path%/}" != "$path" ]; do
    path=${path%/}
  done
  printf '%s\n' "$path"
}

reject_parent_reference() {
  case "/$1/" in
    */../*) die "'..' components are not allowed: $1" ;;
  esac
}

reject_symlink_components() {
  probe=$1
  while [ "$probe" != / ]; do
    [ ! -L "$probe" ] || die "symlink component is not allowed: $probe"
    next=$(dirname -- "$probe")
    [ "$next" != "$probe" ] || die "cannot inspect path components: $1"
    probe=$next
  done
}

reject_parent_reference "$scratch_root"
reject_parent_reference "$scratch_dir"
root_spelling=$(normalize_trailing_slashes \
  "$(absolute_spelling "$scratch_root")")
dir_spelling=$(normalize_trailing_slashes \
  "$(absolute_spelling "$scratch_dir")")
reject_symlink_components "$root_spelling"
reject_symlink_components "$dir_spelling"

[ -d "$root_spelling" ] || die "scratch root is not an existing directory"
root=$(realpath -e -- "$root_spelling") ||
  die "cannot canonicalize scratch root"

existing=$dir_spelling
while [ ! -e "$existing" ] && [ ! -L "$existing" ]; do
  next=$(dirname -- "$existing")
  [ "$next" != "$existing" ] || die "scratch directory has no parent"
  existing=$next
done
[ -d "$existing" ] || die "existing scratch parent is not a directory"
realpath -e -- "$existing" >/dev/null ||
  die "cannot canonicalize existing scratch parent"

[ ! -e "$dir_spelling" ] || [ -d "$dir_spelling" ] ||
  die "scratch directory exists and is not a directory"
scratch=$(realpath -m -- "$dir_spelling") ||
  die "cannot canonicalize scratch directory"
[ "$scratch" != "$root" ] ||
  die "scratch directory is not a strict descendant of $root"
case "$root" in
  /) root_prefix=/ ;;
  *) root_prefix=$root/ ;;
esac
case "$scratch" in
  "$root_prefix"*) ;;
  *) die "scratch directory is not a strict descendant of $root" ;;
esac

printf '%s\n' "$scratch"
