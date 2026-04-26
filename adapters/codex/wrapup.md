---
name: wrapup
description: >
  End-of-session wrap-up: summarizes the session and pushes a log to the
  project's linked NotebookLM notebook. Trigger on /wrapup, "wrap up",
  "save this session", or "end of session".
---

# Session Wrap-Up

Runs at end of session to capture decisions and push a searchable log to
the project's NotebookLM notebook.

---

## Step 1 — Find target notebook

```bash
cat "$(pwd)/.notebooklm/config.json" 2>/dev/null
```

Extract `notebook_id` and set as active. If config missing, tell the user to
run `/notebooklm init` first.

---

## Step 2 — Review the session

Look back through the conversation and identify:

- **Work completed** — what was built, fixed, or configured
- **Decisions made** — what was decided and why
- **Key learnings** — non-obvious insights
- **Open threads** — unfinished items for next session

---

## Step 3 — Write session log

Create `.notebooklm/sessions/session-YYYY-MM-DD.md`:

```markdown
# Session Summary — YYYY-MM-DD

**Project:** <project name>

## What We Did
- ...

## Decisions Made
- ...

## Key Learnings
- ...

## Open Threads
- ...

## Tools & Systems Touched
- ...
```

---

## Step 4 — Push to NotebookLM

```bash
mkdir -p .notebooklm/sessions
NOTEBOOK_ID=$(python3 -c "import json,pathlib; print(json.loads(pathlib.Path('.notebooklm/config.json').read_text())['notebook_id'])")
notebooklm source add ".notebooklm/sessions/session-$(date +%F).md" --notebook "$NOTEBOOK_ID"
```

---

## Step 5 — Confirm

Tell the user: what was captured, where saved, and open threads for next time.
