#!/usr/bin/env bash
# notebooklm-skill installer — macOS and Linux
# https://github.com/ibaifernandez/notebooklm-skill
set -e

VENV_DIR="$HOME/.notebooklm-venv"
BIN_DIR="$HOME/bin"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     notebooklm-skill installer           ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── 1. Check Python ──────────────────────────────────────────────────────────
echo "→ Checking Python..."
PYTHON=$(command -v python3.12 2>/dev/null \
      || command -v python3.11 2>/dev/null \
      || command -v python3.10 2>/dev/null \
      || command -v python3 2>/dev/null)

if [ -z "$PYTHON" ]; then
  echo "✗ Python 3.10+ not found. Install it and try again."
  echo "  macOS: brew install python@3.12"
  echo "  Linux: sudo apt install python3.12"
  exit 1
fi

PY_VERSION=$("$PYTHON" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PY_MAJOR=$("$PYTHON" -c "import sys; print(sys.version_info.major)")
PY_MINOR=$("$PYTHON" -c "import sys; print(sys.version_info.minor)")

if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 10 ]; }; then
  echo "✗ Python $PY_VERSION is too old. Need 3.10+."
  exit 1
fi
echo "  Python $PY_VERSION at $PYTHON ✓"

# ── 2. Install uv (if not present) ──────────────────────────────────────────
echo ""
echo "→ Checking for uv..."
if command -v uv &>/dev/null; then
  echo "  uv already installed ✓"
  USE_UV=1
else
  echo "  uv not found — installing (much faster than pip)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # Add uv to PATH for this script
  export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
  if command -v uv &>/dev/null; then
    echo "  uv installed ✓"
    USE_UV=1
  else
    echo "  uv install failed, falling back to pip"
    USE_UV=0
  fi
fi

# ── 3. Create venv ───────────────────────────────────────────────────────────
echo ""
echo "→ Creating virtual environment at $VENV_DIR..."
rm -rf "$VENV_DIR"

if [ "$USE_UV" -eq 1 ]; then
  uv venv "$VENV_DIR" --python "$PYTHON"
else
  "$PYTHON" -m venv "$VENV_DIR"
fi
echo "  Virtual environment created ✓"

# ── 4. Install notebooklm-py ─────────────────────────────────────────────────
echo ""
echo "→ Installing notebooklm-py..."
if [ "$USE_UV" -eq 1 ]; then
  uv pip install "notebooklm-py[browser]" --python "$VENV_DIR/bin/python"
else
  "$VENV_DIR/bin/pip" install "notebooklm-py[browser]"
fi
echo "  notebooklm-py installed ✓"

# ── 5. Install Chromium ──────────────────────────────────────────────────────
echo ""
echo "→ Installing Playwright Chromium (~200 MB, first time only)..."
"$VENV_DIR/bin/playwright" install chromium
echo "  Chromium installed ✓"

# ── 6. Add to PATH ───────────────────────────────────────────────────────────
echo ""
echo "→ Creating symlink in ~/bin..."
mkdir -p "$BIN_DIR"
ln -sf "$VENV_DIR/bin/notebooklm" "$BIN_DIR/notebooklm"

# Detect shell profile
SHELL_PROFILE=""
if [ -f "$HOME/.zshrc" ]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_PROFILE="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
  SHELL_PROFILE="$HOME/.bash_profile"
fi

if [ -n "$SHELL_PROFILE" ]; then
  if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$SHELL_PROFILE" 2>/dev/null; then
    echo '' >> "$SHELL_PROFILE"
    echo '# notebooklm-skill' >> "$SHELL_PROFILE"
    echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_PROFILE"
    echo "  Added ~/bin to PATH in $SHELL_PROFILE ✓"
  else
    echo "  ~/bin already in PATH ✓"
  fi
fi
export PATH="$BIN_DIR:$PATH"

# ── 7. Install AI assistant skills ──────────────────────────────────────────
# Locate the directory that contains this script (the repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_INSTALLED=0

echo ""
echo "→ Installing AI assistant skills..."

# Claude Code — skills must live as ~/.claude/skills/<name>/SKILL.md
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
if [ -d "$HOME/.claude" ] || command -v claude &>/dev/null; then
  mkdir -p "$CLAUDE_SKILLS_DIR/notebooklm"
  mkdir -p "$CLAUDE_SKILLS_DIR/wrapup"
  cp "$SCRIPT_DIR/skills/notebooklm.md" "$CLAUDE_SKILLS_DIR/notebooklm/SKILL.md"
  cp "$SCRIPT_DIR/skills/wrapup.md"     "$CLAUDE_SKILLS_DIR/wrapup/SKILL.md"
  echo "  Claude Code skills installed → $CLAUDE_SKILLS_DIR ✓"
  SKILLS_INSTALLED=1
else
  echo "  Claude Code not detected — skipping (install manually if needed)"
fi

# OpenAI Codex — same directory structure: ~/.codex/skills/<name>/SKILL.md
CODEX_SKILLS_DIR="$HOME/.codex/skills"
if [ -d "$HOME/.codex" ]; then
  mkdir -p "$CODEX_SKILLS_DIR/notebooklm"
  mkdir -p "$CODEX_SKILLS_DIR/wrapup"
  cp "$SCRIPT_DIR/adapters/codex/notebooklm.md" "$CODEX_SKILLS_DIR/notebooklm/SKILL.md"
  cp "$SCRIPT_DIR/adapters/codex/wrapup.md"     "$CODEX_SKILLS_DIR/wrapup/SKILL.md"
  echo "  OpenAI Codex skills installed → $CODEX_SKILLS_DIR ✓"
  SKILLS_INSTALLED=1
else
  echo "  OpenAI Codex not detected — skipping (install manually if needed)"
fi

if [ "$SKILLS_INSTALLED" -eq 0 ]; then
  echo ""
  echo "  ⚠  No AI assistant detected automatically."
  echo "  Install skills manually — see README.md → Step 2."
fi

# ── 8. Verify ────────────────────────────────────────────────────────────────
echo ""
echo "→ Verifying installation..."
VERSION=$(notebooklm --version 2>&1)
echo "  $VERSION ✓"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  Installation complete!                  ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Next step: authenticate with Google."
echo ""
echo "If you use Claude Code, open any project and run:"
echo "  /notebooklm"
echo ""
echo "Claude will open a browser window for Google login."
echo "Once you're on notebooklm.google.com, confirm to Claude"
echo "and it will save the session automatically."
echo ""
echo "If you use Cursor, copy the adapter files manually:"
echo "  mkdir -p .cursor/rules"
echo "  cp $SCRIPT_DIR/adapters/cursor/*.mdc .cursor/rules/"
echo ""
echo "To reload your shell (so notebooklm is on PATH):"
if [ -n "$SHELL_PROFILE" ]; then
  echo "  source $SHELL_PROFILE"
fi
echo ""
