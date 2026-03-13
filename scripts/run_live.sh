#!/usr/bin/env bash
set -euo pipefail

export COCOTB_LOG_LEVEL=${COCOTB_LOG_LEVEL:-INFO}
export PYTHONUNBUFFERED=1

pytest -vv tb/test_runner.py -s
