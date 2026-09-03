#!/usr/bin/env bash
# Local productization smoke (prod-002..004). Run from repo root with elan + sbpf on PATH.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.elan/bin:${HOME}/.cargo/bin:${HOME}/.local/bin:/usr/local/bin:${PATH}"

python3 scripts/check_ownership.py
python3 scripts/check_sdk_import_closure.py
lake build ProofForgeSvmSdk pf

echo "== registry Counter (digest-pinned) =="
rm -rf /tmp/pf-smoke-svm
lake exe pf -- build --target svm --module Examples.Counter --out /tmp/pf-smoke-svm
test -f /tmp/pf-smoke-svm/Counter.so

echo "== pf init templates =="
rm -rf /tmp/pf-smoke-init-svm
# init into sibling dirs under /tmp won't path-require monorepo; use repo-local scratch
rm -rf .smoke-svm
lake exe pf -- init .smoke-svm
( cd .smoke-svm && lake build && lake exe pf -- build --module MyProgram.Counter --out build/out && test -f build/out/Counter.so )
rm -rf .smoke-svm

lake exe pf -- --version
echo "smoke_productization: ok"
