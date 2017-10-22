#!/bin/bash
set -e

export LUA_PATH="$LUA_PATH;$TRAVIS_BUILD_DIR/?.lua;;"
export KONG_CUSTOM_PLUGINS=consumer-rate-limiting