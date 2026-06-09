#!/usr/bin/env bash
#
# branchnew installer
#   ./install.sh            install the `branchnew` command into ~/.local/bin
#   ./install.sh --hotkey   ALSO install the iTerm2 ⌃⌥⌘F fork daemon
#                           (see HOTKEY-FORK.md)
#
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
  echo "branchnew is macOS-only (it drives iTerm2 / Apple Terminal via AppleScript)." >&2
  exit 1
fi

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$HOME/.local/bin"
DEST="$DEST_DIR/branchnew"

mkdir -p "$DEST_DIR"
install -m 0755 "$SRC_DIR/branchnew" "$DEST"
echo "✓ installed: $DEST"

# Make sure ~/.local/bin is on PATH.
case ":$PATH:" in
  *":$DEST_DIR:"*)
    echo "✓ $DEST_DIR is already on PATH"
    ;;
  *)
    RC="$HOME/.zshrc"
    LINE='export PATH="$HOME/.local/bin:$PATH"'
    if ! grep -qsF "$LINE" "$RC" 2>/dev/null; then
      printf '\n# added by branchnew installer\n%s\n' "$LINE" >> "$RC"
      echo "✓ added $DEST_DIR to PATH in $RC"
    fi
    echo "  → open a new terminal (or run: source $RC) to pick it up"
    ;;
esac

# Friendly heads-up if the claude CLI isn't visible yet.
if ! command -v claude >/dev/null 2>&1; then
  echo "! note: 'claude' was not found on PATH — install Claude Code so branchnew has something to launch."
fi

# ── Optional: the iTerm2 hotkey (⌃⌥⌘F) fork daemon. ───────────────────────────
if [[ "${1:-}" == "--hotkey" ]]; then
  AL="$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch"
  mkdir -p "$AL"
  install -m 0644 "$SRC_DIR/iterm2/claude_fork.py" "$AL/claude_fork.py"
  echo "✓ installed iTerm2 hotkey daemon: $AL/claude_fork.py"
  echo
  echo "To finish hotkey (⌃⌥⌘F) setup:"
  echo "  1. iTerm2 → Settings → General → Magic → enable \"Enable Python API\""
  echo "  2. Add these two hooks to ~/.claude/settings.json (one command each):"
  echo "        SessionStart     →  $DEST --record"
  echo "        UserPromptSubmit →  $DEST --record"
  echo "  3. Restart iTerm2 (allow the script when prompted), start a Claude"
  echo "     session, then press ⌃⌥⌘F in that pane."
  echo "  See HOTKEY-FORK.md for details."
fi

echo
echo "Done. Try:  branchnew --help"
