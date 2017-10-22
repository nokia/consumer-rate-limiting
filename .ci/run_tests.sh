#!/bin/bash
set -e

(cd $KONG_DOWNLOAD; bin/busted $TRAVIS_BUILD_DIR/spec)