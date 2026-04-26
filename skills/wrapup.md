---
name: wrapup
description: >
  End-of-session wrap-up: summarizes the session, saves key memories, and
  pushes a session log to the project's linked NotebookLM notebook (or a global
  AI Brain notebook if no project is active). Trigger on "/wrapup", "wrap up",
  "save this session", "end of session", or "session summary".
---

# Session Wrap-Up

Runs at the end of every session to capture what happened, persist key memories,
and push a searchable log to NotebookLM.

---

## Step 0 — Determine target notebook

There are two possible targets, in priority order:

### A) Project notebook (preferred)

Check if the current working directory has a project notebook linked:

```bash
cat "$(pwd)/.notebooklm/config.json" 2>/dev/null
```

If found and `notebook_id` is set, use that notebook. Set `TARGET_TYPE=project`.

### B) Brain notebook (fallback)

If no project notebook, look for a global AI Brain notebook.

Check memory index for a file named `reference_brain_notebook.md`. If found,
read the `notebook_id` from it.

If not found, list existing notebooks and look for one titled "AI Brain":

```bash
export PATH="$HOME/bin:$PATH"
notebooklm list --json
```

If found, save the ID to memory. If not found, ask the user:
> You don't have a Brain notebook yet — this is where I save a log of every
> session so you can query your history over time. Want me to create one now?

If yes: `notebooklm create "AI Brain" --json` and save the ID to a memory file:

```markdown
---
name: Brain notebook reference
description: ID of the global AI Brain notebook in NotebookLM
type: reference
---

Notebook ID: <ID>
Title: AI Brain
Created: <YYYY-MM-DD>
```

Update `MEMORY.md` index. Set `TARGET_TYPE=brain`.

---

## Step 1 — Review the session

Look back through the entire conversation and identify:

- **Work completed** — what was built, fixed, or configured
- **Decisions made** — what was decided and why
- **Key learnings** — anything non-obvious that came up
- **Open threads** — unfinished items to pick up next time
- **User preferences revealed** — feedback about how the user likes to work

---

## Step 2 — Save memories

Check the existing memory index at
`~/.claude/projects/<project-slug>/memory/MEMORY.md`.

Save or update memories as needed:

- **feedback** — corrections or confirmed approaches from this session
- **project** — ongoing work, goals, deadlines that future sessions need
- **user** — anything new about the user's role, preferences, or knowledge
- **reference** — external tools, URLs, or systems referenced

Rules:
- Don't duplicate existing memories — update them instead
- Don't save things derivable from code or git history
- Convert relative dates to absolute dates (e.g. "Thursday" → "2026-05-01")
- For feedback and project memories: lead with the rule/fact, then add
  **Why:** and **How to apply:** lines

---

## Step 3 — Write the session summary

Create a markdown session log. Keep it concise but complete.

```markdown
# Session Summary — YYYY-MM-DD

**Project:** <project name or "general">
**Notebook:** <notebook title>

## What We Did
- Bullet points of key work completed

## Decisions Made
- Decisions and their reasoning

## Key Learnings
- Non-obvious insights or discoveries

## Open Threads
- Anything to pick up next time

## Tools & Systems Touched
- List of tools, repos, services involved
```

Save to:
- Project session: `<project-path>/.notebooklm/sessions/session-YYYY-MM-DD.md`
- Brain session: `/tmp/session-YYYY-MM-DD.md`

If multiple sessions on the same day, append a counter (e.g. `-2.md`).

---

## Step 4 — Push to NotebookLM

### If TARGET_TYPE=project:

```bash
export PATH="$HOME/bin:$PATH"
NOTEBOOK_ID=$(python3 -c "import json,pathlib; print(json.loads(pathlib.Path('.notebooklm/config.json').read_text())['notebook_id'])")
notebooklm source add ./.notebooklm/sessions/session-YYYY-MM-DD.md --notebook "$NOTEBOOK_ID"
```

### If TARGET_TYPE=brain:

```bash
notebooklm source add /tmp/session-YYYY-MM-DD.md --notebook "$BRAIN_NOTEBOOK_ID"
```

If auth fails: save memories locally, skip the notebook push, tell the user.

---

## Step 5 — Confirm

Tell the user:
- How many memories were saved or updated
- Whether the session log was pushed to the project notebook or Brain
- Any open threads to pick up next time

Keep it brief — one short paragraph.

---

## Error handling

- **Auth fails:** save memories locally, skip notebook push, note it to user
- **Project notebook deleted:** remove from config, offer to create a new one
- **Nothing meaningful to save:** just say so, don't force empty memories
- **`notebooklm` not found:** try `~/.notebooklm-venv/bin/notebooklm`;
  if missing, tell user to install (see `notebooklm.md` Step 0)
