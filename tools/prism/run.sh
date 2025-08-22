#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

$SCRIPT_DIR/node_modules/.bin/prism mock --verbose-level=trace $SCRIPT_DIR/../pet-store/bigger.yaml
