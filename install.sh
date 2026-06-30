#!/usr/bin/env bash
#
# branchnew installer.
#
# One-liner (no clone needed):
#   curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/install.sh | bash -s -- --hotkey
# From a clone:
#   ./install.sh [--hotkey]
#
# Base install : the `branchnew` command + the `/branchnew` slash command.
# --hotkey also: wires the hotkey fork for your platform:
#   macOS  : iTerm2 ⌘F daemon + Ghostty fork script + Claude hooks
#   WSL/WT : tmux bind-key (reliable, both OMP & Claude) + WT sendInput snippet
#            (degraded: Claude-only via /branchnew; OMP needs idle shell)
#   Linux  : tmux bind-key
#
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/limin112/branchnew/main"

OS="$(uname)"

# Detect WSL (Windows Subsystem for Linux)
is_wsl=0
if [[ "$OS" == "Linux" ]]; then
  if [[ -n "${WSL_DISTRO_NAME:-}" || -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
    is_wsl=1
  fi
fi

WANT_HOTKEY=0
[[ "${1:-}" == "--hotkey" ]] && WANT_HOTKEY=1

# Source files: use the clone we're running from, otherwise download them.
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [[ -z "$SRC_DIR" || ! -f "$SRC_DIR/branchnew" ]]; then
  SRC_DIR="$(mktemp -d)"
  trap 'rm -rf "$SRC_DIR"' EXIT
  echo "↓ downloading branchnew from GitHub…"
  for f in branchnew branchnew-hotkey commands/branchnew.md iterm2/claude_fork.py ghostty/fork.sh; do
    mkdir -p "$SRC_DIR/$(dirname "$f")"
    curl -fsSL "$REPO_RAW/$f" -o "$SRC_DIR/$f"
  done
fi

# 1) the branchnew command
DEST_DIR="$HOME/.local/bin"
DEST="$DEST_DIR/branchnew"
mkdir -p "$DEST_DIR"
install -m 0755 "$SRC_DIR/branchnew" "$DEST"
echo "✓ installed: $DEST"

# 1b) the branchnew-hotkey command (tmux-layer hotkey fork)
HOTKEY_DEST="$DEST_DIR/branchnew-hotkey"
install -m 0755 "$SRC_DIR/branchnew-hotkey" "$HOTKEY_DEST"
echo "✓ installed: $HOTKEY_DEST"

case ":$PATH:" in
  *":$DEST_DIR:"*) echo "✓ $DEST_DIR is on PATH" ;;
  *)
    LINE='export PATH="$HOME/.local/bin:$PATH"'
    # Pick the right rc file: zshrc on macOS, bashrc on Linux/WSL (fall back to whatever exists)
    if [[ "$OS" == "Darwin" ]]; then
      RC="$HOME/.zshrc"
    else
      RC="$HOME/.bashrc"
      [[ -f "$HOME/.bashrc" ]] || RC="$HOME/.profile"
    fi
    if ! grep -qsF "$LINE" "$RC" 2>/dev/null; then
      printf '\n# added by branchnew installer\n%s\n' "$LINE" >> "$RC"
      echo "✓ added $DEST_DIR to PATH in $RC"
    fi
    echo "  → open a new terminal (or run: source $RC) to pick it up"
    ;;
esac

# 2) the /branchnew slash command
CMD_DIR="$HOME/.claude/commands"
mkdir -p "$CMD_DIR"
install -m 0644 "$SRC_DIR/commands/branchnew.md" "$CMD_DIR/branchnew.md"
echo "✓ installed /branchnew slash command"

command -v claude >/dev/null 2>&1 || echo "! note: 'claude' is not on PATH — install Claude Code."

# 3) optional: hotkey daemon + auto-wired hooks
if [[ "$WANT_HOTKEY" == 1 ]]; then

  # Wire the two recorder hooks into ~/.claude/settings.json (idempotent, backed up).
  # (Claude-only; OMP maintains its own terminal-sessions mapping.)
  python3 - "$DEST" <<'PY' || true
import json, os, sys, shutil
dest = sys.argv[1]
p = os.path.expanduser("~/.claude/settings.json")
os.makedirs(os.path.dirname(p), exist_ok=True)
d = {}
if os.path.exists(p):
    shutil.copy(p, p + ".bak")
    try:
        with open(p) as f: d = json.load(f)
    except Exception:
        sys.exit("! ~/.claude/settings.json isn't valid JSON — add the hooks by hand (see HOTKEY-FORK.md).")
hooks = d.setdefault("hooks", {})
cmd = dest + " --record"
def ensure(ev):
    arr = hooks.setdefault(ev, [])
    if any(h.get("command", "").strip() == cmd for blk in arr for h in blk.get("hooks", [])):
        return False
    arr.append({"hooks": [{"type": "command", "command": cmd}]}); return True
changed = ensure("SessionStart") | ensure("UserPromptSubmit")
with open(p, "w") as f: json.dump(d, f, indent=2, ensure_ascii=False)
print("✓ wired SessionStart/UserPromptSubmit → branchnew --record" if changed else "✓ hooks already wired")
PY

  echo
  if [[ "$OS" == "Darwin" ]]; then
    # ── macOS: iTerm2 Python API daemon + Ghostty fork script ──
    if [[ "${TERM_PROGRAM:-}" == "iTerm.app" || -d "/Applications/iTerm.app" ]]; then
      AL="$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch"
      mkdir -p "$AL"
      install -m 0644 "$SRC_DIR/iterm2/claude_fork.py" "$AL/claude_fork.py"
      echo "✓ installed iTerm2 hotkey daemon"
    fi
    if [[ "${TERM_PROGRAM:-}" == "ghostty" || -d "/Applications/Ghostty.app" ]]; then
      install -m 0755 "$SRC_DIR/ghostty/fork.sh" "$DEST_DIR/ghostty-fork"
      echo "✓ installed ghostty-fork script"
    fi

    echo
    if [[ "${TERM_PROGRAM:-}" == "iTerm.app" || -d "/Applications/iTerm.app" ]]; then
      echo "iTerm2 hotkey (⌘F):"
      echo "  1. iTerm2 → Settings → General → Magic → enable \"Enable Python API\""
      echo "  2. Restart iTerm2 and click \"Allow\" when it asks about claude_fork.py"
      echo "  Then open a Claude session and press ⌘F.   (details: HOTKEY-FORK.md)"
      echo
    fi
    if [[ "${TERM_PROGRAM:-}" == "ghostty" || -d "/Applications/Ghostty.app" ]]; then
      echo "Ghostty hotkey:"
      echo "  Bind 'ghostty-fork' to a keyboard shortcut via macOS Shortcuts,"
      echo "  Raycast, or Hammerspoon. Example Hammerspoon config:"
      echo "    hs.hotkey.bind({\"cmd\"}, \"f\", function() hs.execute(\"ghostty-fork\") end)"
      echo "  The script uses Ghostty's AppleScript API to split right and fork."
      echo
    fi

  else
    # ── Linux / WSL: tmux bind-key (the reliable hotkey path) ──
    command -v tmux >/dev/null 2>&1 || {
      echo "! tmux not found — install it (apt install tmux) for the hotkey fork." >&2
      echo "  Without tmux you can still run 'branchnew' manually; WT sendInput is a" >&2
      echo "  degraded hotkey (Claude only, see below)." >&2
    }

    # Write tmux bind-key to ~/.tmux.conf (idempotent, backed up)
    TMUX_CONF="$HOME/.tmux.conf"
    [[ -f "$TMUX_CONF" ]] && cp "$TMUX_CONF" "$TMUX_CONF.bak" 2>/dev/null || true
    # Bind F (after prefix) to fork right, and S-F to fork down. -n binds without prefix.
    # Using prefix-less keys so it's one keystroke like iTerm2's ⌘F; adjust to taste.
    MARKER="# branchnew-hotkey"
    if ! grep -qsF "$MARKER" "$TMUX_CONF" 2>/dev/null; then
      {
        printf '\n%s\n' "$MARKER"
        printf 'bind-key -n M-f run-shell "%s"\n' "$HOTKEY_DEST"
        printf 'bind-key -n M-S-f run-shell "%s --down"\n' "$HOTKEY_DEST"
      } >> "$TMUX_CONF"
      echo "✓ wired tmux bind-key: Alt+F (fork right), Alt+Shift+F (fork down) in $TMUX_CONF"
      echo "  (reload: tmux source-file $TMUX_CONF, or restart tmux)"
    else
      echo "✓ tmux bind-key already wired in $TMUX_CONF"
    fi

    # WSL / Windows Terminal degraded fallback: sendInput snippet
    if [[ "$is_wsl" == 1 ]]; then
      echo
      echo "Windows Terminal degraded hotkey (no tmux needed, Claude-only):"
      echo "  Add to WT settings.json → actions + keybindings (Ctrl+Shift+F):"
      echo '    { "command": { "action": "sendInput", "input": "/branchnew\r" }, "id": "User.BranchnewFork" }'
      echo '    { "keys": "ctrl+shift+f", "id": "User.BranchnewFork" }'
      echo "  Note: this only works in a Claude Code pane (Claude recognizes /branchnew)."
      echo "  OMP has that slash command disabled, so in an OMP pane the chars would be"
      echo "  swallowed by the TUI as a prompt. For OMP, use the tmux bind-key above."
      echo
    fi
  fi
fi

echo
echo "Done.  Inside Claude Code type  /branchnew  — or run  branchnew --help"
