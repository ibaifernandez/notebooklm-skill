# LinkedIn Post — notebooklm-skill

---

I built a thing this weekend.

If you use Claude Code, Cursor, or OpenAI Codex — this one's for you.

**notebooklm-skill** gives your AI coding assistant full access to Google NotebookLM, with one notebook per project that stays in sync automatically.

Here's the problem it solves:

NotebookLM is genuinely powerful for research, synthesis, and generating learning materials. But it sits in a browser tab, completely disconnected from your coding workflow. Your AI assistant doesn't know it exists.

The fix: a skill layer that bridges the two.

Once installed, you type `/notebooklm init` inside any project and your AI:
→ Creates a NotebookLM notebook for that project
→ Scans for docs, READMEs, and source files and adds them as sources
→ Links the notebook to the project via a config file

From then on, `/notebooklm` gives you full access — ask questions about your codebase backed by real documentation, generate podcasts or reports from your project knowledge, sync new sources as you write them.

And at the end of every session, `/wrapup` writes a summary and pushes it to the notebook — so your project builds a searchable history over time.

**Tech notes for the curious:**
- Layer 1 is a universal CLI (notebooklm-py by @teng-lin, wrapped in a clean installer)
- Layer 2 is a skill/adapter system for each AI platform — Claude Code native, Cursor via .mdc rules, Codex via its own skills directory
- MIT license, open source, PRs welcome

It took me discovering that Claude Code and OpenAI Codex use nearly identical skill formats to decide this was worth making into a proper multi-platform project.

GitHub: https://github.com/ibaifernandez/notebooklm-skill

Would love to know what AI assistant you're using and whether you'd want an adapter for it. 👇

---

*Hashtags (add to post):*
`#AITools` `#DeveloperTools` `#ClaudeCode` `#NotebookLM` `#OpenSource` `#BuildInPublic`
