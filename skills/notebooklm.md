---
name: notebooklm
description: >
  Complete programmatic access to Google NotebookLM — including project-aware
  notebooks, cross-platform setup, and full artifact generation. Activates on
  explicit /notebooklm, on project commands like "init notebooklm", "sync
  sources", "create a podcast about X", or when working in a project that has
  a .notebooklm/config.json file.
---

# NotebookLM Skill

Programmatic access to Google NotebookLM from Claude Code. Supports per-project
notebooks, automatic source syncing, and all artifact types (podcast, video,
quiz, flashcards, slide deck, report, mind map, infographic).

---

## Step 0 — Setup (run automatically on first use)

Only run this section if `notebooklm` is not already installed. Check first:

```bash
notebooklm --version 2>/dev/null || ~/.notebooklm-venv/bin/notebooklm --version 2>/dev/null
```

If a version is printed, skip to Step 1.

### 0.1 — Choose installer: `uv` (preferred) or `pip` (fallback)

**Check for uv first** — it is much faster and avoids `ensurepip` issues that
affect some macOS Homebrew and Linux system Python installations:

```bash
which uv 2>/dev/null && echo "uv available" || echo "uv not found"
```

**If uv is available:** use it for everything:

```bash
# Detect best Python (3.10+)
PYTHON=$(command -v python3.12 2>/dev/null || command -v python3.11 2>/dev/null || command -v python3.10 2>/dev/null || command -v python3)
$PYTHON -c "import sys; assert sys.version_info >= (3,10), f'Need Python 3.10+, got {sys.version}'; print(f'Python {sys.version}')"

uv venv ~/.notebooklm-venv --python "$PYTHON"
uv pip install "notebooklm-py[browser]" --python ~/.notebooklm-venv/bin/python
```

**If uv is NOT available:** use pip, but prefer Python 3.12 over 3.14 to
avoid missing pre-built wheels for playwright:

```bash
PYTHON=$(command -v python3.12 2>/dev/null || command -v python3.11 2>/dev/null || command -v python3.10 2>/dev/null || command -v python3)
$PYTHON -c "import sys; assert sys.version_info >= (3,10), f'Need Python 3.10+, got {sys.version}'; print(f'Python {sys.version}')"

$PYTHON -m venv ~/.notebooklm-venv
source ~/.notebooklm-venv/bin/activate
pip install "notebooklm-py[browser]"
```

> **Note — uv installation:** If uv is not installed, users can get it with:
> `curl -LsSf https://astral.sh/uv/install.sh | sh` (macOS/Linux) or
> `pip install uv` (any OS). It is highly recommended — installs 50× faster
> than pip and avoids ensurepip/wheel-build hangs.

### 0.2 — Install Chromium browser

```bash
~/.notebooklm-venv/bin/playwright install chromium
```

This installs the Playwright-managed Chromium (not your system browser).
It is needed for the login flow and for generating audio/video artifacts.
Chromium is ~200 MB and is cached in `~/Library/Caches/ms-playwright` (macOS)
or `~/.cache/ms-playwright` (Linux).

### 0.3 — Add to PATH

```bash
mkdir -p ~/bin
ln -sf ~/.notebooklm-venv/bin/notebooklm ~/bin/notebooklm
export PATH="$HOME/bin:$PATH"
```

On Windows (PowerShell) use the full path
`$env:USERPROFILE\.notebooklm-venv\Scripts\notebooklm.exe` instead.

### 0.4 — Authenticate (custom interactive login)

**Important:** The built-in `notebooklm login` command requires interactive
terminal input that Claude Code's bash tool does not support. Use this custom
script instead — it opens a real browser window, waits for the user to sign in,
then captures the session via a signal file.

Tell the user:
> I'm going to open a browser window. Sign into your Google account and
> navigate to notebooklm.google.com. Take your time — tell me when you're
> on the NotebookLM home page and I'll capture the session.

Write and run the login script:

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

print("Opening browser — sign in to Google and go to notebooklm.google.com")

with sync_playwright() as p:
    browser = p.chromium.launch_persistent_context(
        user_data_dir=str(PROFILE_PATH),
        headless=False,
        args=["--disable-blink-features=AutomationControlled"],
    )
    page = browser.pages[0] if browser.pages else browser.new_page()
    page.goto("https://notebooklm.google.com/")
    print("Browser open. Waiting for save signal at /tmp/nlm_save_signal ...")
    while not SIGNAL_FILE.exists():
        time.sleep(1)
    print("Signal received — saving session...")
    storage = browser.storage_state()
    with open(STORAGE_PATH, "w") as f:
        json.dump(storage, f)
    names = [c["name"] for c in storage.get("cookies", [])]
    print(f"Saved {len(names)} cookies: {names}")
    browser.close()

SIGNAL_FILE.unlink(missing_ok=True)
print(f"Auth saved to: {STORAGE_PATH}")
PYEOF

source ~/.notebooklm-venv/bin/activate
python3 /tmp/nlm_login.py > /tmp/nlm_login_output.txt 2>&1 &
echo "Login PID=$! — browser opening in a few seconds"
```

Wait ~10 seconds, then ask the user if the browser opened. Once they confirm
they are on NotebookLM's home page:

```bash
touch /tmp/nlm_save_signal && sleep 8 && cat /tmp/nlm_login_output.txt
```

Verify auth and list existing notebooks:

```bash
export PATH="$HOME/bin:$PATH"
notebooklm auth check
notebooklm list
```

If auth fails (no SID cookie), delete the profile and retry:

```bash
rm -rf ~/.notebooklm/browser_profile ~/.notebooklm/storage_state.json
```

Clean up temp files:

```bash
rm -f /tmp/nlm_login.py /tmp/nlm_login_output.txt /tmp/nlm_save_signal
```

---

## Step 1 — Project context detection

Before running any notebook command, determine which notebook to use.

### 1.1 — Check for per-project config

Look for `.notebooklm/config.json` in the current working directory:

```bash
cat "$(pwd)/.notebooklm/config.json" 2>/dev/null
```

If found, use `notebook_id` from that file as the active notebook:

```bash
export PATH="$HOME/bin:$PATH"
NOTEBOOK_ID=$(python3 -c "
import json, pathlib
cfg = pathlib.Path('.notebooklm/config.json')
if cfg.exists():
    print(json.loads(cfg.read_text())['notebook_id'])
")
notebooklm use "$NOTEBOOK_ID"
```

### 1.2 — Check global registry fallback

If no per-project config, check `~/.notebooklm/registry.json`:

```bash
python3 -c "
import json, os, pathlib
reg = pathlib.Path.home() / '.notebooklm' / 'registry.json'
if reg.exists():
    data = json.loads(reg.read_text())
    cwd = os.getcwd()
    if cwd in data:
        print(data[cwd]['notebook_id'])
"
```

### 1.3 — No project context

If neither file exists, tell the user:
> No NotebookLM notebook linked to this project. Run `/notebooklm init` to
> create one, or use `notebooklm use <id>` to link an existing notebook.

---

## Command: `/notebooklm init`

Initialize a NotebookLM notebook for the current project.

**Steps:**

1. **Create the notebook:**
   ```bash
   export PATH="$HOME/bin:$PATH"
   PROJECT_NAME=$(basename "$(pwd)")
   notebooklm create "$PROJECT_NAME" --json
   ```
   Save the returned `id` as `NOTEBOOK_ID`.

2. **Set as active context:**
   ```bash
   notebooklm use "$NOTEBOOK_ID"
   ```

3. **Detect sources to add** — scan the project for useful files:
   - `README.md`, `CLAUDE.md`, `AGENTS.md` (project documentation)
   - `docs/` directory (any `.md` files)
   - `src/content/` or `content/` directories (any `.md` files)
   - Live URL if project has one (check `package.json` for homepage, or ask user)

4. **Add each source:**
   ```bash
   notebooklm source add ./README.md --json
   notebooklm source add ./docs/  # for each .md file in docs/
   ```

5. **Create `.notebooklm/config.json`** in the project:
   ```json
   {
     "notebook_id": "<NOTEBOOK_ID>",
     "notebook_title": "<PROJECT_NAME>",
     "project_path": "<ABSOLUTE_CWD>",
     "created_at": "<YYYY-MM-DD>",
     "auto_sources": ["README.md", "CLAUDE.md", "docs/"],
     "live_url": null
   }
   ```
   Ask the user if they have a live URL to add and update `live_url` accordingly.

6. **Update global registry** `~/.notebooklm/registry.json`:
   ```python
   import json, os
   from pathlib import Path

   reg_path = Path.home() / ".notebooklm" / "registry.json"
   registry = json.loads(reg_path.read_text()) if reg_path.exists() else {}
   registry[os.getcwd()] = {
       "notebook_id": NOTEBOOK_ID,
       "notebook_title": PROJECT_NAME,
       "created_at": TODAY
   }
   reg_path.write_text(json.dumps(registry, indent=2))
   ```

7. **Confirm to the user:**
   > Notebook `<PROJECT_NAME>` created and linked to this project.
   > Added X sources — all ready for queries.
   > Run `/notebooklm sync` any time to refresh sources after changes.

---

## Command: `/notebooklm sync`

Re-sync sources from the project to its notebook, based on `auto_sources` in
`.notebooklm/config.json`. Useful after adding new docs or changing content.

**Steps:**

1. Load config and set notebook context (Step 1 above).
2. List current sources: `notebooklm source list --json`
3. For each path in `auto_sources`:
   - If it's a file, add it: `notebooklm source add <file> --json`
   - If it's a directory, add each `.md` and `.txt` file inside it
4. If `live_url` is set, add it: `notebooklm source add <url> --json`
5. Report how many new sources were added.

> Note: NotebookLM does not support updating an existing source — it only
> supports adding new ones. If a source was changed, advise the user to delete
> the old version via the NotebookLM web UI and run sync again.

---

## Autonomy rules

**Run automatically (no confirmation needed):**
- `notebooklm auth check`
- `notebooklm list`
- `notebooklm status`
- `notebooklm use <id>`
- `notebooklm source list`
- `notebooklm source wait`
- `notebooklm artifact list`
- `notebooklm artifact wait`
- `notebooklm language list` / `get` / `set`
- `notebooklm research status` / `wait`
- `notebooklm ask "..."` (without `--save-as-note`)
- `notebooklm history`
- `notebooklm create`
- `notebooklm source add`

**Ask before running:**
- `notebooklm delete` — destructive
- `notebooklm generate *` — long-running, may take minutes or fail
- `notebooklm download *` — writes to filesystem
- `notebooklm ask "..." --save-as-note` — writes a note
- `notebooklm history --save` — writes a note

---

## Quick reference

| Task | Command |
|------|---------|
| Init project notebook | `/notebooklm init` |
| Sync sources | `/notebooklm sync` |
| Show active context | `notebooklm status` |
| List notebooks | `notebooklm list` |
| Set active notebook | `notebooklm use <id>` |
| Add URL | `notebooklm source add "https://..."` |
| Add file | `notebooklm source add ./file.md` |
| Add YouTube | `notebooklm source add "https://youtube.com/..."` |
| List sources | `notebooklm source list` |
| Chat | `notebooklm ask "question"` |
| Chat (JSON + refs) | `notebooklm ask "question" --json` |
| Save answer as note | `notebooklm ask "question" --save-as-note` |
| Web research | `notebooklm source add-research "query"` |
| Generate podcast | `notebooklm generate audio "focus on X"` |
| Generate video | `notebooklm generate video "instructions"` |
| Generate report | `notebooklm generate report --format briefing-doc` |
| Generate quiz | `notebooklm generate quiz` |
| Generate flashcards | `notebooklm generate flashcards` |
| Generate infographic | `notebooklm generate infographic` |
| Generate mind map | `notebooklm generate mind-map` |
| Generate slide deck | `notebooklm generate slide-deck` |
| Wait for artifact | `notebooklm artifact wait <id>` |
| Download audio | `notebooklm download audio ./output.mp3` |
| Download video | `notebooklm download video ./output.mp4` |
| Download report | `notebooklm download report ./report.md` |
| Download slides (PDF) | `notebooklm download slide-deck ./slides.pdf` |
| Download slides (PPTX) | `notebooklm download slide-deck ./slides.pptx --format pptx` |
| Download quiz | `notebooklm download quiz quiz.json` |

## Generation types

| Type | Command | Options |
|------|---------|---------|
| Podcast | `generate audio` | `--format [deep-dive\|brief\|critique\|debate]`, `--length [short\|default\|long]` |
| Video | `generate video` | `--format [explainer\|brief]`, `--style [auto\|classic\|whiteboard\|kawaii\|anime\|...]` |
| Slide deck | `generate slide-deck` | `--format [detailed\|presenter]` |
| Infographic | `generate infographic` | `--orientation [landscape\|portrait\|square]` |
| Report | `generate report` | `--format [briefing-doc\|study-guide\|blog-post\|custom]` |
| Mind map | `generate mind-map` | *(instant, sync)* |
| Quiz | `generate quiz` | `--difficulty [easy\|medium\|hard]` |
| Flashcards | `generate flashcards` | `--difficulty [easy\|medium\|hard]` |

All generation commands support `-s <source_id>` to limit to specific sources
and `--language <code>` to set output language.

---

## Error handling

| Error | Cause | Fix |
|-------|-------|-----|
| `Auth/cookie error` | Session expired | Re-run the login script in Step 0.4 |
| `No notebook context` | Context not set | Run `notebooklm use <id>` or `/notebooklm init` |
| `ensurepip` hangs on macOS | Homebrew Python bug | Use `uv` instead (see Step 0.1) |
| `playwright not found` | Playwright not installed | Run Step 0.2 again |
| Rate limiting | Google throttle | Wait 5–10 min, retry |
| Download fails | Generation incomplete | Check `notebooklm artifact list` |

## Known limitations

- NotebookLM has no official public API — this uses the unofficial `notebooklm-py`
  library, which drives the web UI via Playwright. Google may change things
  without notice.
- Audio and video generation can take 10–45 minutes and may fail due to Google
  rate limits. Use `--retry 3` to auto-retry.
- Sources cannot be updated in-place — delete via the web UI, then sync again.
- Session cookies expire after some days. Re-run login when auth check fails.
