# Installer PTY harness

`install.sh` prompts through a real terminal, so its interactive paths need a
PTY to exercise. Run this harness from a real Linux shell (a Windows host
shell cannot allocate one, so Git Bash users go through WSL):

```bash
wsl.exe -e bash -c 'cd /mnt/c/path/to/heddlework && tests/pty/run-case.sh <case-name>'
```

Cases (each drives `install.sh` through `tests/pty/pty-run.py`):

- `menu-default` — Enter at the harness menu selects the Heddlework path.
- `menu-pi` — option 2 selects the Pi + Fabric harness and runs its install.
- `hidden-input` — a configured provider key is never echoed to the terminal.
- `already-configured` — detection works when only Node is installed.
- `ctrl-c` — interrupt during hidden input restores terminal echo.
- `eof-default` — EOF at the menu falls back to the default harness.
- `bun-prompt-decline` — declining the Bun install stops without installing.
- `bun-install-accept` — accepting runs the installer (curl is mocked).
- `auth-write` — real Node writes auth.json with mode 0600. Skipped when no
  real Node is resolvable outside the case's PATH shim; set
  `PTY_REAL_NODE=/abs/path/to/node` to enable it (e.g. a Node that is not on
  `PATH` at all).
- `desktop-launcher` — `packaging/linux/install-user.sh` completes on a PTY,
  stages binary/web/icon/launcher/desktop entry correctly, and the produced
  launcher executes through to the installed binary in the chosen workspace.

The PTY transcript for each case lands in `/tmp` and the runner asserts on it
(see `run-case.sh`).
