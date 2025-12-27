#!/bin/bash
set -u
ARGS=()
echo "Testing [*]"
echo "Arguments: ${ARGS[*]:-}"
echo "Testing [@] quoted"
echo "Arguments: \"${ARGS[@]}\""
echo "Testing [@] unquoted"
echo "Arguments: ${ARGS[@]}"
