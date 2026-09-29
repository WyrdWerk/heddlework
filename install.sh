#!/bin/sh
# Heddlework installer: picks a harness and configures API providers.
#
#   ./install.sh              # interactive menu
#   ./install.sh heddle       # Heddlework + Pi (native desktop harness)
#   ./install.sh pi           # Pi plus Fabric (plain TUI harness)
#   ./install.sh pi-fabric    # alias of `pi`
#
# Honors: NO_COLOR=1, HEDDLEWORK_NONINTERACTIVE=1, HEDDLEWORK_PI, HEDDLEWORK_PROVIDER,
#         HEDDLEWORK_MODEL, HEDDLEWORK_SKIP_PROVIDERS=1, HEDDLEWORK_SKIP_SETUP=1.
set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# ---------------------------------------------------------------------------
# Presentation helpers
# ---------------------------------------------------------------------------
if [ -t 1 ] && [ "${NO_COLOR:-}" != "1" ]; then
  BOLD=$(printf '\033[1m'); DIM=$(printf '\033[2m'); RESET=$(printf '\033[0m')
else
  BOLD=''; DIM=''; RESET=''
fi

info()  { printf '%s\n' "${BOLD}==>${RESET} $*"; }
warn()  { printf '%s\n' "${BOLD}warning:${RESET} $*" >&2; }
die()   { printf '%s\n' "${BOLD}error:${RESET} $*" >&2; exit 1; }

is_interactive() {
  [ "${HEDDLEWORK_NONINTERACTIVE:-0}" != "1" ] && [ -t 0 ]
}

# ---------------------------------------------------------------------------
# Host tool detection (best effort: Homebrew on macOS, apt/dnf/pacman otherwise)
# ---------------------------------------------------------------------------
PKG_INSTALL=''
if command -v brew >/dev/null 2>&1; then
  PKG_INSTALL='brew install'
elif command -v apt-get >/dev/null 2>&1; then
  PKG_INSTALL='sudo apt-get install -y'
elif command -v dnf >/dev/null 2>&1; then
  PKG_INSTALL='sudo dnf install -y'
elif command -v pacman >/dev/null 2>&1; then
  PKG_INSTALL='sudo pacman -S --noconfirm'
fi

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
need_node() {
  command -v node >/dev/null 2>&1 && return 0
  warn "Node.js is required to run Pi (https://nodejs.org)"
  return 1
}

need_bun() {
  command -v bun >/dev/null 2>&1 && return 0
  info "Bun 1.3+ is required to build Heddlework"
  if is_interactive; then
    printf 'Install Bun now (curl -fsSL https://bun.sh/install | bash)? [y/N] '
    read -r answer
    case "$answer" in
      y|Y|yes|YES)
        curl -fsSL https://bun.sh/install | bash
        export PATH="$HOME/.bun/bin:$PATH"
        command -v bun >/dev/null 2>&1 && return 0 ;;
    esac
  fi
  warn "install Bun from https://bun.sh"
  return 1
}

# ---------------------------------------------------------------------------
# Pi installation
# ---------------------------------------------------------------------------
install_pi() {
  if command -v pi >/dev/null 2>&1; then
    info "Pi is already installed: $(command -v pi)"
    return 0
  fi
  need_node || return 1
  info "Installing Pi (@earendil-works/pi-coding-agent) globally with npm"
  # --ignore-scripts is what Pi's own docs recommend.
  npm install -g --ignore-scripts @earendil-works/pi-coding-agent
  command -v pi >/dev/null 2>&1 || die "pi was installed but is not on PATH; check your npm global bin directory"
  info "Pi installed: $(pi --version 2>/dev/null || command -v pi)"
}

# ---------------------------------------------------------------------------
# Fabric installation (pi install npm:pi-fabric)
# ---------------------------------------------------------------------------
install_fabric() {
  info "Installing pi-fabric (Pi Fabric: tools, agents, workflows, mesh)"
  pi install npm:pi-fabric
  info "pi-fabric installed; manage it any time with 'pi install' / 'pi remove' or /fabric settings inside Pi"
}

# ---------------------------------------------------------------------------
# API provider setup — writes ~/.pi/agent/auth.json
#
# Pi's auth.json maps provider name -> { "type": "api_key", "key": "..." }.
# Provider keys are also honored from the environment at runtime
# (ANTHROPIC_API_KEY, OPENAI_API_KEY, ...); writing them to auth.json is
# optional and is done here with owner-only file permissions (0600).
# ---------------------------------------------------------------------------
# Pi honors PI_CODING_AGENT_DIR itself (sessions, auth.json live there).
PI_DIR="${PI_CODING_AGENT_DIR:-${PI_CONFIG_DIR:-$HOME/.pi/agent}}"
AUTH_FILE="$PI_DIR/auth.json"

provider_env_var() {
  case "$1" in
    anthropic) printf 'ANTHROPIC_API_KEY' ;;
    openai)    printf 'OPENAI_API_KEY' ;;
    google)    printf 'GEMINI_API_KEY' ;;
    xai)       printf 'XAI_API_KEY' ;;
    openrouter) printf 'OPENROUTER_API_KEY' ;;
    groq)      printf 'GROQ_API_KEY' ;;
    cerebras)  printf 'CEREBRAS_API_KEY' ;;
    mistral)   printf 'MISTRAL_API_KEY' ;;
    deepseek)  printf 'DEEPSEEK_API_KEY' ;;
    *)         printf '' ;;
  esac
}

provider_default_model() {
  case "$1" in
    anthropic) printf 'claude-sonnet-4-5' ;;
    openai)    printf 'gpt-5.1-codex' ;;
    google)    printf 'gemini-2.5-pro' ;;
    *)         printf '' ;;
  esac
}

KNOWN_PROVIDERS='anthropic openai google xai openrouter groq cerebras mistral deepseek'

write_auth_entry() { # write_auth_entry <provider> <key>
  provider=$1
  key=$2
  mkdir -p "$PI_DIR"
  # Args travel through the environment: bun and node disagree about argv offsets under `-e`.
  if command -v bun >/dev/null 2>&1; then
    PI_AUTH_FILE="$AUTH_FILE" PI_AUTH_PROVIDER="$provider" PI_AUTH_KEY="$key" \
      bun -e 'const fs=require("node:fs");let auth={};try{auth=JSON.parse(fs.readFileSync(process.env.PI_AUTH_FILE,"utf8"))}catch{};auth[process.env.PI_AUTH_PROVIDER]={type:"api_key",key:process.env.PI_AUTH_KEY};fs.writeFileSync(process.env.PI_AUTH_FILE,JSON.stringify(auth,null,2)+"\n",{mode:0o600})'
  elif command -v node >/dev/null 2>&1; then
    PI_AUTH_FILE="$AUTH_FILE" PI_AUTH_PROVIDER="$provider" PI_AUTH_KEY="$key" \
      node -e 'const fs=require("node:fs");let auth={};try{auth=JSON.parse(fs.readFileSync(process.env.PI_AUTH_FILE,"utf8"))}catch{};auth[process.env.PI_AUTH_PROVIDER]={type:"api_key",key:process.env.PI_AUTH_KEY};fs.writeFileSync(process.env.PI_AUTH_FILE,JSON.stringify(auth,null,2)+"\n",{mode:0o600})'
  else
    die "node or bun is required to write $AUTH_FILE"
  fi
  chmod 600 "$AUTH_FILE" 2>/dev/null || true
}

setup_providers() {
  if [ "${HEDDLEWORK_SKIP_PROVIDERS:-0}" = "1" ]; then
    info "HEDDLEWORK_SKIP_PROVIDERS=1 — skipping provider setup"
    return 0
  fi
  info "API provider setup"
  printf '%s\n' "Pi reads keys from the environment at runtime (ANTHROPIC_API_KEY, OPENAI_API_KEY, ...)"
  printf '%s\n' "or stores them in $AUTH_FILE (chmod 600, never commit it)."

  # Interactive: offer each known provider in turn.
  if is_interactive; then
    for provider in $KNOWN_PROVIDERS; do
      env_var=$(provider_env_var "$provider")
      current="not set"
      if [ -n "$env_var" ] && [ -n "$(eval "printf '%s' \"\${$env_var:-}\"")" ]; then
        current="set in environment"
      elif [ -f "$AUTH_FILE" ] && { command -v bun >/dev/null 2>&1 || command -v node >/dev/null 2>&1; }; then
        if command -v bun >/dev/null 2>&1; then
          JS_RUNTIME=$(command -v bun)
        else
          JS_RUNTIME=$(command -v node)
        fi
        if PI_AUTH_FILE="$AUTH_FILE" PI_AUTH_PROVIDER="$provider" "$JS_RUNTIME" -e 'let a={};try{a=JSON.parse(require("node:fs").readFileSync(process.env.PI_AUTH_FILE,"utf8"))}catch{};process.stdout.write(a[process.env.PI_AUTH_PROVIDER]?"configured":"not set")' 2>/dev/null | grep -q configured; then
          current="already in $AUTH_FILE"
        fi
      fi
      printf 'Configure %s API key? [%s] [y/N] ' "$provider" "$current"
      read -r answer
      case "$answer" in
        y|Y|yes|YES) ;;
        *) continue ;;
      esac
      # Turn off echo BEFORE printing the prompt: if the prompt came first,
      # a fast keypress could land between prompt and `stty -echo` and echo.
      # Restore on every exit path, including Ctrl-C mid-entry.
      saved_stty=$(stty -g 2>/dev/null || true)
      trap 'stty "$saved_stty" 2>/dev/null || stty echo 2>/dev/null || true; printf '\n'; exit 130' INT
      stty -echo 2>/dev/null || true
      printf 'Paste the %s API key (input hidden, Ctrl-C cancels): ' "$provider"
      old_ifs=$IFS
      IFS= read -r key || true
      IFS=$old_ifs
      stty "$saved_stty" 2>/dev/null || stty echo 2>/dev/null || true
      trap - INT
      printf '\n'
      [ -n "$key" ] || { warn "empty key for $provider — skipped"; continue; }
      write_auth_entry "$provider" "$key"
      info "$provider key written to $AUTH_FILE"
    done
  fi

  # Non-interactive / explicit: pick up provider keys from the environment.
  for provider in $KNOWN_PROVIDERS; do
    env_var=$(provider_env_var "$provider")
    [ -n "$env_var" ] || continue
    key=$(eval "printf '%s' \"\${$env_var:-}\"")
    [ -n "$key" ] || continue
    if [ ! -f "$AUTH_FILE" ] || ! grep -q "\"$provider\"" "$AUTH_FILE" 2>/dev/null; then
      write_auth_entry "$provider" "$key"
      info "$provider key copied from $env_var into $AUTH_FILE"
    fi
  done

  # Initial provider/model hints for the desktop app.
  if [ -n "${HEDDLEWORK_PROVIDER:-}" ] && [ -n "${HEDDLEWORK_MODEL:-}" ]; then
    info "HEDDLEWORK_PROVIDER=$HEDDLEWORK_PROVIDER HEDDLEWORK_MODEL=$HEDDLEWORK_MODEL will be passed to Pi on launch"
  elif [ -n "${HEDDLEWORK_PROVIDER:-}" ]; then
    default=$(provider_default_model "$HEDDLEWORK_PROVIDER")
    [ -n "$default" ] && warn "set HEDDLEWORK_MODEL too (e.g. $default) to pin the startup model"
  fi
  info "Subscription-based providers (GitHub Copilot, OAuth flows) can be configured later with 'pi /login'"
}

# ---------------------------------------------------------------------------
# Harness builds
# ---------------------------------------------------------------------------
build_heddlework() {
  need_bun || die "Bun is required for the Heddlework harness"
  cd "$REPO_ROOT"
  info "Installing workspace dependencies (bun install --frozen-lockfile)"
  bun install --frozen-lockfile
  if [ "${HEDDLEWORK_SKIP_SETUP:-0}" != "1" ]; then
    info "Building the pinned GPUIX native runtime (Rust toolchain required)"
    bun run setup:native
  fi
  info "Building Heddlework"
  bun run build
  info "Built $(cd "$REPO_ROOT" && pwd)/dist — run it with: ./dist/heddlework /path/to/repository"
}

verify_pi() {
  command -v pi >/dev/null 2>&1 || die "pi is not on PATH after installation"
  info "pi: $(command -v pi)"
  if pi --help 2>&1 | grep -q -- '--mode'; then
    info "Pi RPC mode is available (--mode rpc) — Heddlework will drive it as a sidecar"
  fi
}

# ---------------------------------------------------------------------------
# Harness selection
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: install.sh [harness]

Harnesses:
  heddle      Heddlework + Pi — the native GPUIX desktop harness (default prompt)
  pi          Pi + Fabric — the plain terminal harness with pi-fabric installed
  pi-fabric   alias of `pi`

Options (environment):
  HEDDLEWORK_NONINTERACTIVE=1   never prompt; use flags/env only
  HEDDLEWORK_SKIP_PROVIDERS=1   do not touch ~/.pi/agent/auth.json
  HEDDLEWORK_SKIP_SETUP=1       skip the slow GPUIX native build (`bun run setup:native`)
  HEDDLEWORK_PI=/abs/path/pi    absolute Pi path for desktop launchers
  HEDDLEWORK_PROVIDER=...       initial provider passed to Pi
  HEDDLEWORK_MODEL=...          initial model passed to Pi

Examples:
  ./install.sh                    # interactive menu
  ./install.sh heddle             # desktop harness
  HEDDLEWORK_PROVIDER=anthropic HEDDLEWORK_MODEL=claude-sonnet-4-5 ./install.sh pi
EOF
}

select_harness() {
  if [ "${1:-}" = "pi-fabric" ]; then
    printf 'pi'
    return 0
  fi
  case "${1:-}" in
    heddle|pi) printf '%s' "$1"; return 0 ;;
    '') ;;
    *) die "unknown harness '$1' (expected: heddle, pi, pi-fabric)" ;;
  esac

  if ! is_interactive; then
    die "no harness specified; pass 'heddle' or 'pi' (or run interactively)"
  fi
  # The caller captures this function's stdout, so the menu and prompt belong
  # on stderr — only the harness name may travel through stdout.
  cat >&2 <<'EOF'

Which harness should this machine use?

  1) Heddlework + Pi   — native GPUIX desktop workspace; Pi runs as an RPC sidecar
                         (builds the pinned native runtime; needs Rust)
  2) Pi + Fabric       — plain Pi TUI with pi-fabric installed; no Heddlework build
                         (fastest path; only needs Node.js)

EOF
  printf 'Choose [1/2, default 1]: ' >&2
  # Ctrl-D at the prompt must fall through to the default harness, not abort
  # the installer (read returns non-zero on EOF; set -e would kill the script).
  read -r choice || true
  case "${choice:-1}" in
    2) printf 'pi' ;;
    *) printf 'heddle' ;;
  esac
}

main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
  esac
  harness=$(select_harness "$@")

  info "Heddlework installer — harness: ${BOLD}$harness${RESET}"

  install_pi
  verify_pi

  case "$harness" in
    pi)
      install_fabric
      ;;
    heddle)
      build_heddlework
      ;;
  esac

  setup_providers

  printf '\n'
  info "Done. Next steps:"
  if [ "$harness" = "heddle" ]; then
    printf '  %s./dist/heddlework /path/to/repository%s   # native desktop\n' "$BOLD" "$RESET"
    printf '  %sbun run demo /path/to/repository%s        # no credentials, no Pi process\n' "$BOLD" "$RESET"
    printf '  %sbun run host /path/to/repository%s        # headless web workspace (see Dockerfile)\n' "$BOLD" "$RESET"
    if is_interactive && [ "$(uname -s)" = "Linux" ]; then
      printf '  %sHEDDLEWORK_PI="$(command -v pi)" ./packaging/linux/install-user.sh%s  # app menu entry\n' "$BOLD" "$RESET"
    fi
  else
    printf '  %spi /path/to/repository%s                  # start the TUI\n' "$BOLD" "$RESET"
    printf '  %s/fabric%s inside Pi opens the Fabric dashboard; /fabric settings tunes it\n' "$BOLD" "$RESET"
  fi
  printf '  %spi /login%s subscribes OAuth providers (Copilot etc.); API keys above are already wired\n' "$BOLD" "$RESET"
}

main "$@"
