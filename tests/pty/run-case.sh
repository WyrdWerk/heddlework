#!/usr/bin/env bash
# Drive install.sh interactive paths under a real PTY and assert on the result.
# The desktop-launcher case drives packaging/linux/install-user.sh instead.
# Usage: tests/pty/run-case.sh <case-name>
set -eu

REPO=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
CASE=${1:?usage: run-case.sh <case-name>}
WORK=$(mktemp -d)
LOG="$WORK/transcript.log"
PY=/usr/bin/python3

export PI_CODING_AGENT_DIR="$WORK/pi-agent"
export HEDDLEWORK_SKIP_SETUP=1
export HEDDLEWORK_NONINTERACTIVE=0
export PATH="$REPO/tests/pty:$PATH"
unset ANTHROPIC_API_KEY OPENAI_API_KEY || true
# The WSL sandbox has no Node; `need_node` only checks availability, so a
# mock keeps the pi-harness path reachable. Writing auth.json falls back to
# node, which must therefore also resolve (mock-pi handles any argv).
mkdir -p "$WORK/bin"
ln -sf "$REPO/tests/pty/mock-pi.sh" "$WORK/bin/pi"
ln -sf "$REPO/tests/pty/mock-pi.sh" "$WORK/bin/node"
export PATH="$WORK/bin:$PATH"

fail() { printf 'FAIL(%s): %s\n' "$CASE" "$*" >&2; exit 1; }
pass() { printf 'PASS(%s): %s\n' "$CASE" "$*"; }
CASE_HARNESS_ARGS=()
# One of: menu-default menu-pi hidden-input already-configured ctrl-c
#         eof-default bun-prompt-decline bun-install-accept auth-write
#         desktop-launcher

run_steps() { # steps-file extra-env...
  local steps=$1; shift
  env "$@" "$PY" "$REPO/tests/pty/pty-run.py" "$LOG" "$steps" -- \
    sh "$REPO/install.sh" "${CASE_HARNESS_ARGS[@]}"
}

# ---------------------------------------------------------------------------
case "$CASE" in
  menu-default)
    CASE_HARNESS_ARGS=()
    printf 'WAIT:Choose [1/2\nENTER\n' > "$WORK/steps"
    # Bun is absent in WSL, so the heddle path continues into the Bun prompt;
    # the selection itself is proven by the harness line.
    run_steps "$WORK/steps" HEDDLEWORK_SKIP_PROVIDERS=1 || true
    grep -aq 'harness: .*heddle' "$LOG" || fail "menu default did not select heddle"
    pass "Enter selected the heddle harness"
    ;;

  hidden-input)
    CASE_HARNESS_ARGS=(pi)
    printf 'WAIT:Configure anthropic\ny\nWAIT:input hidden\nsk-ant-SECRET-VALUE-123\n' > "$WORK/steps"
    run_steps "$WORK/steps" HEDDLEWORK_SKIP_PROVIDERS=0 || true
    if grep -q 'sk-ant-SECRET-VALUE-123' "$LOG"; then
      fail "API key echoed to the terminal"
    fi
    grep -q 'anthropic key written' "$LOG" || fail "key was not accepted"
    pass "key hidden during input and accepted"
    ;;

  already-configured)
    CASE_HARNESS_ARGS=(pi)
    mkdir -p "$PI_CODING_AGENT_DIR"
    printf '{"anthropic":{"type":"api_key","key":"sk-existing"}}\n' > "$PI_CODING_AGENT_DIR/auth.json"
    printf 'WAIT:Configure anthropic\nENTER\n' > "$WORK/steps"
    run_steps "$WORK/steps" HEDDLEWORK_SKIP_PROVIDERS=0 || true
    grep -q 'anthropic API key? \[already in' "$LOG" || fail "existing key not detected (node fallback)"
    pass "existing auth.json entry detected without bun"
    ;;

  # This case proves write_auth_entry against real Node (when available): the
  # mocked pi answers prompts, real node writes auth.json.
  #
  # The PATH shim above fakes node only so `need_node` passes, so look for a
  # real interpreter outside it. Set PTY_REAL_NODE=/abs/path/to/node to point
  # at one that is not on PATH at all (nvm, a tarball under /tmp, ...).
  auth-write)
    CASE_HARNESS_ARGS=(pi)
    real_node=${PTY_REAL_NODE:-}
    if [ -z "$real_node" ]; then
      real_node=$(PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -vx -- "$WORK/bin" | tr '\n' ':' | sed 's/:$//') \
        command -v node 2>/dev/null || true)
    fi
    if [ -z "$real_node" ] || [ ! -x "$real_node" ]; then
      printf 'SKIP(auth-write): no real node outside the PATH shims (set PTY_REAL_NODE to enable)\n'
      exit 0
    fi
    mkdir -p "$PI_CODING_AGENT_DIR"
    ln -sf "$real_node" "$WORK/bin/node"
    printf 'WAIT:Configure anthropic\ny\nWAIT:input hidden\nsk-ant-AUTHWRITE-1\nWAIT:Configure openai\nENTER\n' > "$WORK/steps"
    run_steps "$WORK/steps" HEDDLEWORK_SKIP_PROVIDERS=0 || true
    grep -q 'anthropic key written' "$LOG" || fail "key was not accepted"
    grep -q '"type": "api_key"' "$PI_CODING_AGENT_DIR/auth.json" || fail "auth.json not written"
    grep -q 'sk-ant-AUTHWRITE-1' "$PI_CODING_AGENT_DIR/auth.json" || fail "auth.json missing the key"
    stat -c '%a' "$PI_CODING_AGENT_DIR/auth.json" | grep -Eq '^600$' || fail "auth.json is not 0600"
    pass "node fallback wrote auth.json with 0600"
    ;;

  ctrl-c)
    CASE_HARNESS_ARGS=(pi)
    printf 'WAIT:input hidden\ny-never-sent\nCTRLC\n' > "$WORK/steps"
    set +e
    run_steps "$WORK/steps" HEDDLEWORK_SKIP_PROVIDERS=0
    status=$?
    set -e
    if [ "$status" -eq 0 ]; then
      fail "installer exited 0 after Ctrl-C"
    fi
    grep -q '^\^\?C' "$LOG" || true # terminal shows the interrupt; no assert needed
    pass "Ctrl-C during hidden input exited non-zero"
    # Invariant: nothing crashed with an unset-variable error.
    if grep -q 'unbound variable\|not found.*stty' "$LOG"; then
      fail "unexpected error during Ctrl-C handling"
    fi
    ;;

  menu-pi)
    CASE_HARNESS_ARGS=()
    # Option 2 selects the pi + fabric harness; SKIP_PROVIDERS keeps the case
    # to the selection itself (fabric install output is the final proof).
    printf 'WAIT:Choose [1/2\n2\nWAIT:pi-fabric\nENTER\n' > "$WORK/steps"
    run_steps "$WORK/steps" HEDDLEWORK_SKIP_PROVIDERS=1 || true
    grep -aq 'harness: .*pi' "$LOG" || fail "option 2 did not select pi"
    grep -aq 'Installing pi-fabric' "$LOG" || fail "fabric install did not run"
    pass "option 2 selected the pi + fabric harness"
    ;;

  bun-prompt-decline)
    CASE_HARNESS_ARGS=()
    # Decline the Bun install at the heddle path's need_bun prompt.
    printf 'WAIT:Choose [1/2\nENTER\nWAIT:Bun 1.3\nENTER\n' > "$WORK/steps"
    run_steps "$WORK/steps" HEDDLEWORK_SKIP_PROVIDERS=1 || true
    grep -aq 'install Bun from https://bun.sh' "$LOG" || fail "decline did not warn"
    grep -aq 'Bun is required for the Heddlework harness' "$LOG" || fail "installer did not stop after decline"
    # The prompt itself mentions curl; a real invocation echoes `curl-mock:`.
    grep -aq 'curl-mock:' "$LOG" && fail "installer ran curl after decline"
    pass "declining the Bun prompt stops cleanly without installing"
    ;;

  bun-install-accept)
    CASE_HARNESS_ARGS=()
    # Accept the Bun install with a mocked curl (records the invocation and
    # exits 0); bun remains absent, so the flow then stops with the usual error.
    printf 'WAIT:Choose [1/2\nENTER\nWAIT:Bun 1.3\ny\n' > "$WORK/steps"
    cat > "$WORK/bin/curl" <<'STUB'
#!/bin/sh
echo "curl-mock: $*" >> "${CURL_LOG:?}"
exit 0
STUB
    chmod 755 "$WORK/bin/curl"
    : > "$WORK/curl.log"
    run_steps "$WORK/steps" HEDDLEWORK_SKIP_PROVIDERS=1 CURL_LOG="$WORK/curl.log" || true
    if [ -s "$WORK/curl.log" ]; then
      pass "accepting the prompt attempted the Bun install (curl mocked)"
    else
      fail "accepting the prompt did not run the Bun installer"
    fi
    ;;

  # The desktop launcher installer is non-interactive, but running it under a
  # PTY proves it completes on a terminal (no hidden prompt) and that its
  # staged inputs (absolute pi path, built binary, web dir) compose with the
  # mock environment install.sh uses. Ends by EXECUTING the produced launcher.
  # This case drives packaging/linux/install-user.sh directly, not install.sh.
  desktop-launcher)
    mkdir -p "$WORK/bin-launch" "$WORK/ws" "$WORK/fake-dist/web"
    cat > "$WORK/fake-dist/heddlework" <<'FAKE'
#!/bin/sh
printf 'fake-heddlework-executed cwd=%s args=%s\n' "$PWD" "$*"
FAKE
    chmod 755 "$WORK/fake-dist/heddlework"
    printf '<!doctype html><title>fake web</title>' > "$WORK/fake-dist/web/index.html"
    printf 'WAIT:Installed Heddlework\nEOF\n' > "$WORK/steps"
    env HEDDLEWORK_BUILD="$WORK/fake-dist/heddlework" \
      XDG_DATA_HOME="$WORK/xdg-data" \
      HEDDLEWORK_BIN_DIR="$WORK/bin-launch" \
      HEDDLEWORK_APP_DIR="$WORK/app" \
      "$PY" "$REPO/tests/pty/pty-run.py" "$LOG" "$WORK/steps" -- \
      sh "$REPO/packaging/linux/install-user.sh" || fail "installer exited non-zero"

    [ -x "$WORK/app/heddlework" ] || fail "binary not installed"
    cmp -s "$WORK/app/heddlework" "$WORK/fake-dist/heddlework" || fail "installed binary differs from build"
    [ -f "$WORK/app/web/index.html" ] || fail "web companion not copied"
    icon="$WORK/xdg-data/icons/hicolor/scalable/apps/io.github.monotykamary.heddlework.svg"
    [ -f "$icon" ] || fail "icon not installed"

    launcher="$WORK/bin-launch/heddlework"
    [ -f "$launcher" ] || fail "launcher missing"
    [ "$(stat -c '%a' "$launcher")" = "700" ] || fail "launcher is not 0700"
    grep -q "export HEDDLEWORK_PI='$WORK/bin/pi'" "$launcher" || fail "launcher did not capture the mock pi path"
    sh -n "$launcher" || fail "launcher is not valid shell"

    desktop="$WORK/xdg-data/applications/io.github.monotykamary.heddlework.desktop"
    [ -f "$desktop" ] || fail "desktop entry missing"
    [ "$(stat -c '%a' "$desktop")" = "600" ] || fail "desktop entry is not 0600"
    grep -q '@HEDDLEWORK_EXEC@' "$desktop" && fail "desktop entry still contains the template placeholder"
    grep -q "Exec=\"$launcher\"" "$desktop" || fail "desktop Exec does not point at the launcher"

    # The chain end-to-end: launcher honors HEDDLEWORK_WORKSPACE (cd) and
    # execs the installed binary with forwarded arguments.
    out=$(HEDDLEWORK_WORKSPACE="$WORK/ws" "$launcher" --flag-one)
    printf '%s\n' "$out" | grep -q "fake-heddlework-executed cwd=$WORK/ws args=--flag-one" \
      || fail "launcher execution chain broken: $out"
    pass "desktop launcher installed, staged, and executes through to the binary"
    ;;

  eof-default)
    CASE_HARNESS_ARGS=()
    # EOF (Ctrl-D) at the menu read returns the default harness. Afterwards
    # the heddle path continues into the Bun prompt, where EOF again exits.
    printf 'WAIT:Choose [1/2\nEOF\nWAIT:Bun 1.3\nEOF\n' > "$WORK/steps"
    run_steps "$WORK/steps" HEDDLEWORK_SKIP_PROVIDERS=1 || true
    grep -aq 'harness: .*heddle' "$LOG" || fail "EOF at menu did not fall back to heddle"
    pass "EOF at the menu fell back to the default harness"
    ;;

  *)
    fail "unknown case: $CASE"
    ;;
esac

# The transcript directory is kept for post-mortem inspection:
#   /tmp/heddlework-pty-<case>/transcript.log
printf 'transcript: %s\n' "$LOG"

