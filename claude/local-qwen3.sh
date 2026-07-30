#!/usr/bin/env bash
set -euo pipefail

export ANTHROPIC_BASE_URL="http://127.0.0.1:8787"
export ANTHROPIC_AUTH_TOKEN="ags-local"
export ANTHROPIC_MODEL="qwen3:14b-q4_K_M"
export ANTHROPIC_DEFAULT_SONNET_MODEL="qwen3:14b-q4_K_M"
export ANTHROPIC_DEFAULT_OPUS_MODEL="qwen3:14b-q4_K_M"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="qwen3:14b-q4_K_M"

exec claude "$@"
