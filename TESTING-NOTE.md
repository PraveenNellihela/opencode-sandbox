# Testing Note — 2026-07-22 (updated 2026-07-23)

## Changes Made

### 1. PATH instructions (install.sh, uninstall.sh)
- `install.sh` now prints a single copy-pasteable command to add `~/bin` to PATH (e.g., `echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc`)
- `uninstall.sh` now prints a single copy-pasteable sed command to remove the PATH entry
- No auto-editing of shell config files — user runs the command themselves

### 2. Terminal rendering fix (opencode wrapper)
- Wrapper now passes host env vars into the Docker container: `TERM`, `COLORTERM=truecolor`
- TERM defaults to `xterm-256color` if not set on host
- macOS dark mode detection: if `defaults read -g AppleInterfaceStyle` returns "Dark", also passes `COLORFGBG=12;16`, otherwise `COLORFGBG=0;15`
- Fixes TUI rendering issues (broken colors, "window inside terminal" in VSCode, dark mode visibility)

### 3. install.sh color visibility
- Changed install.sh output colors from low-intensity (`\033[0;31m`, `\033[0;32m`) to bold/high-intensity (`\033[1;31m`, `\033[1;32m`) for visibility on dark terminal backgrounds

### 4. Dockerfile terminal + TUI support
- Replaced `ncurses-base` with `ncurses-term` — provides full terminfo database including `xterm-256color`, which the TUI needs for correct color rendering and layout
- Added `locales` package and generated `en_US.UTF-8` locale — TUI uses unicode box-drawing characters (─, │, ╭) for status bar; without UTF-8 locale these render as garbage
- Set `LANG=en_US.UTF-8` and `LC_ALL=en_US.UTF-8` env vars

### 5. README.md
- Updated shell support table with actual install/uninstall commands

## Root Cause of TUI Issues

The original Dockerfile had zero terminal support packages. The TUI (opencode) requires:
1. **`xterm-256color` terminfo entry** — without it, the TUI falls back to dumb terminal mode, causing dark-on-dark colors and broken layout (e.g. status bar in bottom-left)
2. **UTF-8 locale** — the TUI status bar uses unicode box-drawing characters; without a UTF-8 locale these render as blanks or mojibake

## What to Test

1. **PATH**: Run `./install.sh`, verify it prints the correct command for your shell. Run that command. Open a new terminal, confirm `which opencode` finds it. Then run `./uninstall.sh`, run the printed removal command, open new terminal, confirm `which opencode` is gone.

2. **Terminal rendering**: Run `opencode` in macOS with dark mode enabled. The TUI should render cleanly — no blank screen, no "window inside terminal" artifact, no unreadable dark-on-dark colors. The bottom status bar should display correctly with proper box-drawing characters. Also test on Ubuntu terminal and VSCode integrated terminal.

3. **Syntax check**: `bash -n install.sh && bash -n opencode && bash -n uninstall.sh` should all pass.

4. **Edge cases**: Test with bash, zsh, and fish shells if possible. Test with macOS light mode too (COLORFGBG should use `0;15` not `12;16`).

## Current Uncommitted Diff (3 files changed)

```
Dockerfile | 10 +++++++++-
install.sh |  6 +++---
opencode   | 14 ++++++++++----
```

Full diff captured in git. Run `git diff` to see it.

## Rebuild Required

After pulling these changes, rebuild the Docker image:
```bash
docker build -t local:opencode .
```
