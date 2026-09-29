#!/bin/sh
# Mock `pi` for installer PTY tests.
# `node` is also satisfied by this mock via the same PATH entry (see symlink
# created by run-case.sh) so need_node passes without a real toolchain.
case "$1" in
  --version) echo "pi 0.98.1-mock" ;;
  --help) echo "usage: pi [--mode rpc] [path] [options]" ;;
  install) shift; echo "pi install $* (mock)" ;;
  *) echo "pi $* (mock)" ;;
esac
