---
name: notebooklm
description: >
  Complete programmatic access to Google NotebookLM with per-project notebooks.
  Activates on /notebooklm or intent like "create a podcast about X", "init
  notebooklm", "sync sources", "add these docs to NotebookLM".
---

# NotebookLM Integration

Programmatic access to Google NotebookLM from Codex. Supports per-project
notebooks, automatic source syncing, and artifact generation (podcasts, reports,
quizzes, flashcards, slide decks, mind maps, infographics).

---

## Setup (run once, on first use)

Check if the CLI is already installed:

```bash
notebooklm --version 2>/dev/null || ~/.notebooklm-venv/bin/notebooklm --version 2>/dev/null
```

If not found, run the installer from the repo root:

```bash
chmod +x install.sh && ./install.sh
```

Or manually with uv (recommended — avoids ensurepip issues on macOS/Linux):

```bash
uv venv ~/.notebooklm-venv --python python3.12
uv pip install "notebooklm-py[browser]" --python ~/.notebooklm-venv/bin/python
~/.notebooklm-venv/bin/playwright install chromium
mkdir -p ~/bin && ln -sf ~/.notebooklm-venv/bin/notebooklm ~/bin/notebooklm
export PATH="$HOME/bin:$PATH"
```

### Authentication

The built-in `notebooklm login` requires interactive terminal input that most
AI agent tools don't support. Use this script instead — it opens a real browser:

```bash
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
    print(f"Saved {len(storage.get('cookies', []))} cookies to {STORAGE_PATH}")
    browser.close()
SIGNAL_FILE.unlink(missing_ok=True)
PYEOF

source ~/.notebooklm-venv/bin/activate && python3 /tmp/nlm_login.py &
# Once signed in at notebooklm.google.com, open a new terminal and run:
# touch /tmp/nlm_save_signal
```

Verify: `notebooklm auth check && notebooklm list`

---

## Project context detection

Before any notebook command, check for a linked notebook:

```bash
cat "$(pwd)/.notebooklm/config.json" 2>/dev/null
```

If found, set it as active:

```bash
NOTEBOOK_ID=$(python3 -c "
import json, pathlib
cfg = pathlib.Path('.notebooklm/config.json')
if cfg.exists():
    print(json.loads(cfg.read_text())['notebook_id'])
")
[ -n "$NOTEBOOK_ID" ] && notebooklm use "$NOTEBOOK_ID"
```

---

## Command: /notebooklm init

Initialize a NotebookLM notebook for the current project.

1. Create the notebook:
   ```bash
   PROJECT_NAME=$(basename "$(pwd)")
   notebooklm create "$PROJECT_NAME" --json
   ```
2. Set as active: `notebooklm use <id>`
3. Scan for useful sources: `README.md`, `AGENTS.md`, `CLAUDE.md`, `docs/`, `src/content/`
4. Add each source: `notebooklm source add ./README.md --json`
5. Create `.notebooklm/config.json`:
   ```json
   {
     "notebook_id": "<id>",
     "notebook_title": "<project name>",
     "project_path": "<absolute path>",
     "created_at": "<YYYY-MM-DD>",
     "auto_sources": ["README.md", "AGENTS.md", "docs/"],
     "live_url": null
   }
   ```
6. Update global registry `~/.notebooklm/registry.json` with the new entry.
7. Confirm to the user: notebook created, N sources added, all ready.

---

## Command: /notebooklm sync

Re-add all sources listed in `auto_sources` and `live_url` from config.

```bash
python3 << 'PYEOF'
import json, subprocess
from pathlib import Path

cfg = json.loads(Path(".notebooklm/config.json").read_text())
for source in cfg.get("auto_sources", []):
    p = Path(source)
    if p.is_file():
        subprocess.run(["notebooklm", "source", "add", str(p)])
    elif p.is_dir():
        for f in p.rglob("*.md"):
            subprocess.run(["notebooklm", "source", "add", str(f)])
if cfg.get("live_url"):
    subprocess.run(["notebooklm", "source", "add", cfg["live_url"]])
PYEOF
```

---

## Quick reference

| Task | Command |
|------|---------|
| List notebooks | `notebooklm list` |
| Create notebook | `notebooklm create "Title"` |
| Set active notebook | `notebooklm use <id>` |
| Add file source | `notebooklm source add ./file.md` |
| Add URL source | `notebooklm source add "https://..."` |
| Chat | `notebooklm ask "question"` |
| Generate podcast | `notebooklm generate audio "focus on X"` |
| Generate report | `notebooklm generate report --format briefing-doc` |
| Generate quiz | `notebooklm generate quiz --difficulty medium` |
| Wait for artifact | `notebooklm artifact wait <id>` |
| Download audio | `notebooklm download audio ./output.mp3` |
| Download slides PDF | `notebooklm download slide-deck ./slides.pdf` |
| Download slides PPTX | `notebooklm download slide-deck ./slides.pptx --format pptx` |

## Generation types

| Type | Command | Options |
|------|---------|---------|
| Podcast | `generate audio` | `--format [deep-dive\|brief\|critique\|debate]` |
| Video | `generate video` | `--format [explainer\|brief]` |
| Report | `generate report` | `--format [briefing-doc\|study-guide\|blog-post]` |
| Quiz | `generate quiz` | `--difficulty [easy\|medium\|hard]` |
| Flashcards | `generate flashcards` | `--difficulty [easy\|medium\|hard]` |
| Slide deck | `generate slide-deck` | `--format [detailed\|presenter]` |
| Infographic | `generate infographic` | `--orientation [landscape\|portrait\|square]` |
| Mind map | `generate mind-map` | *(instant)* |

---

## Error handling

| Error | Fix |
|-------|-----|
| Auth/cookie error | Re-run the authentication script above |
| No notebook context | Run `/notebooklm init` or `notebooklm use <id>` |
| `ensurepip` hangs on macOS | Use `uv` instead (see setup above) |
| Rate limiting | Wait 5–10 min, retry |
| `notebooklm` not found | `export PATH="$HOME/bin:$PATH"` or use `~/.notebooklm-venv/bin/notebooklm` |
