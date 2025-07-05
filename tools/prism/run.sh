#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

$SCRIPT_DIR/node_modules/.bin/prism mock $SCRIPT_DIR/../pet-store/bigger.yaml
