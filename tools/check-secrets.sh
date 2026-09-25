#!/bin/sh
# Pre-commit guard: refuse to stage files containing real provider keys.
# Patterns match actual (long) key material; placeholder docs are allowed.
set -eu

patterns='nvapi-[A-Za-z0-9_\-]{10,}|AQ\.Ab[a-zA-Z0-9_\-]{8,}|sk-ant-[A-Za-z0-9_\-]{10,}|sk-[A-Za-z0-9]{20,}|api[_\-]?key["'"'"' ]{0,3}[=:] ?["'"'"'][A-Za-z0-9]{16,}'

hits="$(git diff --cached | grep -nE "$patterns" || true)"
if [ -n "$hits" ]; then
  echo "ERROR: staged changes look like real API keys:" >&2
  echo "$hits" | sed -E 's/(=.{4}).*/\1***/' >&2
  echo "Use assets/secrets.env.default placeholders instead; keep secrets in local secrets.env." >&2
  exit 1
fi
exit 0