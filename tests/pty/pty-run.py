#!/usr/bin/env python3
"""Run install.sh under a real PTY and replay scripted keystrokes.

Usage: pty-run.py <logfile> <script-file> -- <command> [args...]

Steps (one per line):
  text            typed as keystrokes followed by Enter
  ENTER           sends only the Return key
  CTRLC           sends an interrupt character
  EOF             sends the terminal EOF character (Ctrl-D) — a bare Enter
                  at a prompt returns the default; EOF ends the read
  WAIT:<needle>   waits until <needle> appeared in the output (synchronization)
  <<<DELAY:N>>>   sleeps N seconds

With an empty steps file, EOF is sent after a short grace window so a
prompting child observes end-of-input the way a user's Ctrl-D would.
"""
import os
import pty
import select
import signal
import subprocess
import sys
import time


def main() -> int:
    logfile, steps_file = sys.argv[1], sys.argv[2]
    command = sys.argv[sys.argv.index("--") + 1:]
    with open(steps_file, "r", encoding="utf-8") as handle:
        steps = [line.rstrip("\n") for line in handle if line.strip()]

    master, slave = pty.openpty()
    process = subprocess.Popen(
        command,
        stdin=slave, stdout=slave, stderr=slave,
        close_fds=True, start_new_session=True,
    )
    os.close(slave)

    transcript = bytearray()

    def pump(duration: float) -> None:
        end = time.time() + duration
        while time.time() < end:
            try:
                readable, _, _ = select.select([master], [], [], min(0.1, max(0.0, end - time.time())))
            except (OSError, ValueError):
                return
            if not readable:
                continue
            try:
                chunk = os.read(master, 65536)
            except OSError:
                return
            if not chunk:
                return
            transcript.extend(chunk)

    def send(data: bytes) -> None:
        os.write(master, data)

    def shutdown() -> None:
        # The child is its own session (start_new_session), so signals to its
        # process group cannot reach this driver or the surrounding shell.
        if process.poll() is None:
            try:
                os.kill(process.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass

    time.sleep(0.4)
    pump(0.4)

    for step in steps:
        if step.startswith("<<<DELAY:"):
            pump(float(step[len("<<<DELAY:"):-len(">>>")]))
            continue
        if step.startswith("WAIT:"):
            needle = step[len("WAIT:"):].encode()
            end = time.time() + 60
            while time.time() < end:
                if needle in bytes(transcript):
                    break
                pump(0.2)
            continue
        if step == "CTRLC":
            send(b"\x03")
            pump(1.5)
            continue
        if step == "EOF":
            # VEOF (Ctrl-D): delivers end-of-input to a line-discipline read.
            # Two pulses: the first flushes pending echo, the second arrives
            # at an idle line where the EOF applies to the pending read.
            send(b"\x04")
            pump(0.6)
            try:
                send(b"\x04")
            except OSError:
                pass
            pump(1.5)
            continue
        if step == "ENTER":
            send(b"\r")
            pump(1.0)
            continue
        send(step.encode() + b"\r")
        # Wait for a response beyond the terminal echo of the keystrokes.
        baseline = len(transcript)
        end = time.time() + 30
        while time.time() < end:
            pump(0.2)
            if process.poll() is not None:
                break
            if len(transcript) > baseline + len(step) + 1:
                pump(0.5)
                break

    # Drain until exit (bounded). With no scripted steps, send EOF after a
    # short grace window so a prompting child observes end-of-input.
    if not steps:
        time.sleep(0.5)
        pump(0.5)
        try:
            send(b"\x04")
        except OSError:
            pass
        pump(1.0)
        if process.poll() is None:
            try:
                send(b"\x04")
            except OSError:
                pass
            pump(1.0)
    end = time.time() + 30
    while time.time() < end and process.poll() is None:
        pump(0.5)
    if process.poll() is None:
        shutdown()
    time.sleep(0.3)
    pump(1.0)
    try:
        os.close(master)
    except OSError:
        pass

    with open(logfile, "wb") as handle:
        handle.write(bytes(transcript))
    return process.returncode if process.returncode is not None else 1


if __name__ == "__main__":
    sys.exit(main())
