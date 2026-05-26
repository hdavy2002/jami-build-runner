#!/usr/bin/env bash
# patches/03-yaml-cpp-prebuild.sh
#
# Pre-build yaml-cpp in Jami's contrib build directory before the main
# gradle build runs. This works around a missing dependency edge in
# Jami's gradle/CMake graph for Android cross-compile: yaml-cpp is
# listed as an "Automatically selected package" but never actually
# triggered as a build target during configureCMakeDebug, while
# daemon/CMakeLists.txt:637 unconditionally requires it via
#   find_package(yaml-cpp CONFIG REQUIRED)
#
# Result without this step: cmake configure fails on every gradle run
# with "Could not find a package configuration file provided by yaml-cpp".
#
# Idempotent — if .yaml-cpp stamp already exists, the make is a no-op.
#
# Expects:
#   - cwd: jami-client-android repo root (we cd into daemon/contrib below)
#   - ANDROID_ABI env var set (e.g. arm64-v8a)
#   - Jami's daemon/extras/tools build/bin on PATH (autotools, pkg-config)
#   - Jami's bootstrap has already populated daemon/contrib/Makefile etc.

set -euo pipefail

if [ -z "${ANDROID_ABI:-}" ]; then
  echo "ANDROID_ABI must be set (e.g. arm64-v8a)" >&2
  exit 2
fi

# Map gradle's ABI naming to contrib's host-triplet naming.
case "$ANDROID_ABI" in
  arm64-v8a)     CONTRIB_HOST=aarch64-linux-android ;;
  armeabi-v7a)   CONTRIB_HOST=arm-linux-androideabi ;;
  x86_64)        CONTRIB_HOST=x86_64-linux-android ;;
  x86)           CONTRIB_HOST=i686-linux-android ;;
  *)             echo "Unknown ABI: $ANDROID_ABI" >&2; exit 3 ;;
esac

CONTRIB_BUILD_DIR="daemon/contrib/build-${CONTRIB_HOST}"

if [ ! -d "$CONTRIB_BUILD_DIR" ]; then
  echo "Contrib build dir $CONTRIB_BUILD_DIR does not exist yet."
  echo "This script needs to run AFTER the first attempt at the gradle"
  echo "build (which creates the directory and Makefile), OR after the"
  echo "daemon's own bootstrap has materialised it."
  echo ""
  echo "Running daemon's bootstrap to create it now..."
  ( cd daemon && ./compile.sh --daemon ) || true
fi

if [ ! -d "$CONTRIB_BUILD_DIR" ]; then
  echo "Still no contrib build dir after bootstrap. Aborting." >&2
  exit 4
fi

echo "Running 'make .yaml-cpp' in $CONTRIB_BUILD_DIR"
cd "$CONTRIB_BUILD_DIR"
make .yaml-cpp

# Sanity check: the cmake config file find_package will look for.
EXPECTED="$(pwd)/../${CONTRIB_HOST}/lib/cmake/yaml-cpp/yaml-cpp-config.cmake"
if [ ! -f "$EXPECTED" ]; then
  echo "yaml-cpp built but yaml-cpp-config.cmake not found at:" >&2
  echo "  $EXPECTED" >&2
  exit 5
fi

echo "yaml-cpp ready: $EXPECTED"
