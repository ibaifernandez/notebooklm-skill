# notebooklm-skill

Give your AI coding assistant full programmatic access to Google NotebookLM — with **per-project notebooks** that automatically link to your codebase and a **session wrap-up** that saves searchable logs over time.

Works with Claude Code, Cursor, and other AI coding assistants that support instruction files or custom rules.

---

## How it works

This repo has two independent layers:

```
┌─────────────────────────────────────────────────────┐
│  LAYER 1 — Universal CLI (works everywhere)         │
│  install.sh · notebooklm-py · config.json           │
│  No AI assistant required                           │
└─────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────┐
│  LAYER 2 — AI skills (platform-specific)            │
│  Teach your AI assistant to use the CLI             │
│  skills/ → Claude Code                              │
│  adapters/cursor/ → Cursor                          │
└─────────────────────────────────────────────────────┘
```

**Layer 1** installs a CLI tool (`notebooklm`) on your machine, sets up per-project config files, and handles authentication. This is the same regardless of which AI assistant you use.

**Layer 2** are instruction files for your AI assistant. They teach it how to run the CLI, manage per-project notebooks, detect project context, and save session summaries. Different AI platforms use different file formats — pick the one for your tool.

---

## Compatibility

| AI Assistant | Layer 1 | Layer 2 | Files to use |
|---|---|---|---|
| [Claude Code](https://claude.ai/code) | ✅ | ✅ Native | `skills/notebooklm.md` · `skills/wrapup.md` |
| [Cursor](https://cursor.sh) | ✅ | ✅ Adapter | `adapters/cursor/notebooklm.mdc` · `adapters/cursor/wrapup.mdc` |
| [OpenAI Codex](https://openai.com/codex) | ✅ | ✅ Adapter | `adapters/codex/notebooklm.md` · `adapters/codex/wrapup.md` |
| GitHub Copilot | ✅ | ⚠️ Partial | Use Layer 1 + manual instructions |
| Any other agent | ✅ | ⚠️ Manual | See [adapters/README.md](adapters/README.md) |

> Missing your tool? The [adapters guide](adapters/README.md) explains how to port the skills to any platform. PRs welcome.

---

## Prerequisites

- **Python 3.10+**
- **A Google account** with access to [NotebookLM](https://notebooklm.google.com)
- `uv` (strongly recommended) — a fast Python package manager that avoids common install issues on macOS and Linux. Install it with:
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh   # macOS / Linux
  pip install uv                                      # any OS
  ```
  If you skip this, the installer falls back to `pip` automatically.

---

## Step 1 — Install the CLI (everyone)

```bash
git clone https://github.com/ibaifernandez/notebooklm-skill.git
cd notebooklm-skill
chmod +x install.sh && ./install.sh
```

The script:
1. Detects Python 3.10+ (prefers 3.12 for best wheel compatibility)
2. Installs `uv` if missing
3. Creates `~/.notebooklm-venv` with [`notebooklm-py`](https://github.com/sharu725/notebooklm-py)
4. Installs Playwright Chromium (~200 MB, cached after first run)
5. Adds a `notebooklm` symlink to `~/bin`

Verify:
```bash
notebooklm --version
```

---

## Step 2 — Install the skills for your AI assistant

### Claude Code

```bash
cp skills/notebooklm.md ~/.claude/skills/
cp skills/wrapup.md ~/.claude/skills/
```

> Skill directory: `~/.claude/skills/` on macOS/Linux, `%USERPROFILE%\.claude\skills\` on Windows.
> Create it if it doesn't exist: `mkdir -p ~/.claude/skills`

### Cursor

```bash
mkdir -p .cursor/rules
cp adapters/cursor/notebooklm.mdc .cursor/rules/
cp adapters/cursor/wrapup.mdc .cursor/rules/
```

Run this inside each project where you want NotebookLM integration, or copy to a global rules location if your Cursor version supports it.

### OpenAI Codex

Codex supports the same `/skill-name` trigger as Claude Code. Install the
skills in your Codex skills directory (Personal scope) and invoke them with
`/notebooklm` and `/wrapup` in chat.

> **Skills directory:** check Codex → Settings to find where Personal skills
> are stored on your system.

```bash
cp adapters/codex/notebooklm.md ~/.codex/skills/
cp adapters/codex/wrapup.md ~/.codex/skills/
```

Then in Codex chat: `/notebooklm init`, `/notebooklm sync`, `/wrapup`.

### Other assistants

See [adapters/README.md](adapters/README.md).

---

## Step 3 — Authenticate (first time only)

Authentication is handled by your AI assistant during the first `/notebooklm` (Claude Code) or `@notebooklm` (Cursor) invocation. You can also trigger it manually:

**Claude Code:** type `/notebooklm` in any project — Claude detects missing auth and runs the login flow.

**Cursor:** open Cursor in any project and type `@notebooklm authenticate` in chat.

**Manually (any tool):**
```bash
# The built-in "notebooklm login" requires interactive input that most AI
# bash tools don't support. Use this script instead:

cat > /tmp/nlm_login.py << 'PYEOF'
import json, time
from pathlib import Path
from playwright.sync_api import sync_playwright

STORAGE_PATH = Path.home() / ".notebooklm" / "storage_state.json"
PROFILE_PATH = Path.home() / ".notebooklm" / "browser_profile"
SIGNAL_FILE  = Path("/tmp/nlm_save_signal")

SIGNAL_FILE.unlink(missing_ok=True)
STORAGE_PATH.parent.mkdir(parents=True, exist_ok=True)

with sync_playwright() as p:
    browser = p.chromium.launch_persistent_context(
        user_data_dir=str(PROFILE_PATH),
        headless=False,
        args=["--disable-blink-features=AutomationControlled"],
    )
    page = browser.pages[0] if browser.pages else browser.new_page()
    page.goto("https://notebooklm.google.com/")
    print("Sign in to Google, then run: touch /tmp/nlm_save_signal")
    while not SIGNAL_FILE.exists():
        time.sleep(1)
    storage = browser.storage_state()
    STORAGE_PATH.write_text(json.dumps(storage))
    print(f"Saved {len(storage.get('cookies',[]))} cookies to {STORAGE_PATH}")
    browser.close()
SIGNAL_FILE.unlink(missing_ok=True)
PYEOF

source ~/.notebooklm-venv/bin/activate
python3 /tmp/nlm_login.py &

# Once you're signed in and on notebooklm.google.com:
touch /tmp/nlm_save_signal

# Verify
notebooklm auth check
notebooklm list
```

Cookies expire after a few days. Re-run the login flow whenever `notebooklm auth check` fails.

---

## Usage

### Link a project to a notebook

**Claude Code:** `/notebooklm init`

**Cursor:** `@notebooklm init this project`

**Manual:**
```bash
cd your-project
notebooklm create "$(basename $(pwd))" --json
# Note the notebook ID, then:
mkdir -p .notebooklm
cat > .notebooklm/config.json << EOF
{
  "notebook_id": "<ID FROM ABOVE>",
  "notebook_title": "$(basename $(pwd))",
  "project_path": "$(pwd)",
  "created_at": "$(date +%F)",
  "auto_sources": ["README.md", "docs/"],
  "live_url": null
}
EOF
notebooklm use <ID>
notebooklm source add README.md
```

Your AI assistant (Claude Code or Cursor) handles all of this automatically when you use the init command. The manual steps are shown here so you understand what's happening and can use the CLI directly if you prefer.

### Ask questions about your project

```
# In Claude Code:
/notebooklm
> What are the main architectural decisions in this codebase?

# In Cursor chat:
@notebooklm What are the main architectural decisions?

# Direct CLI:
notebooklm ask "What are the main architectural decisions?"
```

### Generate artifacts

```bash
notebooklm generate audio "Focus on the architecture decisions"
notebooklm generate report --format briefing-doc
notebooklm generate quiz --difficulty medium
notebooklm artifact wait <artifact_id>
notebooklm download audio ./podcast.mp3
```

Artifact types: `audio` (podcast), `video`, `report`, `quiz`, `flashcards`, `slide-deck`, `infographic`, `mind-map`.

### Sync sources after changes

```bash
# Claude Code:    /notebooklm sync
# Cursor:         @notebooklm sync sources
# Direct CLI:
notebooklm source add ./docs/new-doc.md
```

### End-of-session wrap-up

```
# Claude Code:    /wrapup
# Cursor:         @wrapup
```

Saves memories, writes a session log, and pushes it to the project's notebook.

---

## Project config

Each project stores its notebook at `.notebooklm/config.json`:

```json
{
  "notebook_id": "9d812075-8f79-4a8b-b398-fdb1ebf91eb2",
  "notebook_title": "my-project",
  "project_path": "/Users/me/projects/my-project",
  "created_at": "2026-04-26",
  "auto_sources": ["README.md", "CLAUDE.md", "docs/"],
  "live_url": "https://my-project.com"
}
```

A global registry at `~/.notebooklm/registry.json` maps project paths to notebook IDs, so the right notebook loads automatically even without the config file.

---

## File layout

```
~/.notebooklm/
  storage_state.json    ← auth cookies (never commit this)
  browser_profile/      ← Playwright browser profile
  registry.json         ← global map: project path → notebook ID

<your-project>/
  .notebooklm/
    config.json         ← per-project notebook config
    sessions/           ← session logs pushed to NotebookLM
```

---

## Supported OS

| Platform | Status | Notes |
|---|---|---|
| macOS (Apple Silicon) | ✅ Tested | Use `uv` — system pip has `ensurepip` issues on some Homebrew setups |
| macOS (Intel) | ✅ Should work | `uv` recommended |
| Linux (Ubuntu / Debian) | ✅ Should work | `sudo apt install python3.12` if needed |
| Windows (WSL2) | 🟡 Likely works | Not yet tested; use WSL2 + `uv` |
| Windows (native) | 🟡 Experimental | Paths will differ; use full venv path |

---

## CLI reference

```
notebooklm auth check           Check authentication status
notebooklm list                 List your notebooks
notebooklm create "Title"       Create a notebook
notebooklm use <id>             Set active notebook
notebooklm status               Show active notebook
notebooklm source add <file>    Add a file source
notebooklm source add <url>     Add a URL source
notebooklm source list          List sources
notebooklm ask "question"       Chat with your notebook
notebooklm generate audio       Generate podcast
notebooklm generate report      Generate report
notebooklm generate quiz        Generate quiz
notebooklm artifact list        List generated artifacts
notebooklm download audio <f>   Download audio artifact
```

Full reference: `notebooklm --help`

---

## Built on

This skill is built on top of [notebooklm-py](https://github.com/teng-lin/notebooklm-py) by [@teng-lin](https://github.com/teng-lin) — an unofficial Python CLI for the NotebookLM web interface.

The idea of wrapping `notebooklm-py` in an AI coding assistant skill was inspired by community experimentation around the library. The per-project notebook architecture, cross-platform installer, and multi-agent adapter system are original additions.

**Important:** NotebookLM has no official public API. `notebooklm-py` drives the web UI via Playwright. Google may change things without warning. If something breaks, update the library:

```bash
uv pip install --upgrade notebooklm-py --python ~/.notebooklm-venv/bin/python
```

---

## Contributing

PRs welcome — especially adapters for new AI platforms. See [adapters/README.md](adapters/README.md) for porting instructions.

To report a bug: OS, Python version, `notebooklm --version`, the failing command, and the error output.

---

MIT License · Built by [Ibai Fernández](https://ibaifernandez.com) · [AGLAYA](https://aglaya.biz)
