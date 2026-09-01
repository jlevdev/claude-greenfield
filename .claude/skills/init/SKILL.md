---
name: init
description: This skill should be used when the user wants to scaffold a fresh project's file structure from the claude-greenfield template — e.g. "set up this project", "scaffold the ticket workflow here", "init this repo from the template" — or says "/init" or "/cg:init". Distinct from Claude Code's built-in codebase-documentation /init: this one lays down the ticket/question/PRD workflow files, not a CLAUDE.md audit of existing code.
allowed-tools: [Read, Write, Bash, Glob, AskUserQuestion]
version: 1.0.0
---

# Init

Scaffold the ticket-based PRD workflow into the current project: `project blurb.md`, `templates/`, `tickets/`, `questions/`, `DECISIONS.md`, `CHANGELOG.md`, and a starter `CLAUDE.md`. Run this once, before `/cg:start-project`, in a project that installed the `cg` plugin but doesn't yet have this scaffolding on disk.

This is a fresh-project setup step, not a codebase audit — don't confuse it with Claude Code's built-in `/init` (which writes a `CLAUDE.md` by reading existing code). If both are ambiguous from context, ask which the user means.

## Steps

1. **Locate the plugin's bundled assets.** They live at `${CLAUDE_PLUGIN_ROOT}/templates/` (also `${CLAUDE_PLUGIN_ROOT}/tickets/`, `${CLAUDE_PLUGIN_ROOT}/questions/` for the empty folder structure, and `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md` for the starter). If `${CLAUDE_PLUGIN_ROOT}` isn't set (e.g. this skill is somehow running standalone rather than as part of the installed plugin), fall back to the current working directory's own `templates/` — but note this to the user, since it means nothing was actually distributed.

2. **Check for conflicts.** Glob the current project root for `project blurb.md`, `templates/`, `tickets/`, `questions/`, `CLAUDE.md`, `DECISIONS.md`, `CHANGELOG.md`. If any already exist with real content (not just an empty dir or placeholder), list them and ask via `AskUserQuestion` whether to skip each one or overwrite it. Never silently clobber existing work — an empty/placeholder file (e.g. a zero-byte `project blurb.md`, or a `CLAUDE.md` that's still the untouched `[Project Name]` template) is safe to overwrite without asking.

3. **Create the scaffold**, skipping anything the user chose to keep:
   - Copy `${CLAUDE_PLUGIN_ROOT}/templates/` → `./templates/` (all seven template files).
   - Recreate the empty ticket/question folder structure with `.gitkeep` placeholders:
     `tickets/{features,remediation}/{todo,in-progress,on-hold,review,done}/.gitkeep`
     `questions/{open,answered}/.gitkeep`
   - Create a blank `project blurb.md` at the project root if one doesn't already exist.
   - Copy `./templates/DECISIONS.md` → `./DECISIONS.md` and `./templates/CHANGELOG.md` → `./CHANGELOG.md` (both unmodified — they're tool-maintained from here on, same as `/cg:start-project` step 3d-iii would otherwise do).
   - Copy `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md` → `./CLAUDE.md`. This is the distributed starter — it already documents the ticket workflow, reviewer subagents, and research standards with the `cg:` invocation prefix; only its top placeholder sections (`[Project Name]`, Tech Stack, etc.) still need filling in, which is `/cg:start-project`'s job, not this skill's.
   - Ensure `.gitignore` contains `research/*` and `.claude/pr-watch-state/` — append whichever lines are missing, create the file if it doesn't exist.

4. **Report what was created and what was skipped**, then point the user at the next step: fill in `project blurb.md` with their idea, then run `/cg:start-project`.

## Notes

- This skill only lays down structure — it never runs `git init` or commits anything. `/cg:start-project` still owns that (its step 3e), so a user can review the scaffold before it's committed.
- If the project has no `.claude-plugin` install context at all (i.e. someone copied these files by hand instead of installing the `cg` plugin), that's fine — the scaffold still works, just without the "pull future updates via `claude plugin update`" benefit. Mention this once if it's the case, don't belabor it.
