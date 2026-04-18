# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository contents

This repo hosts the design and (future) implementation of **Mostly Hot Air** — a local couch-coop game about navigating a single hot-air balloon from A to B. Target engine: **Godot 4**.

- **`BALLON_GDD.md`** — Game Design Document. Markdown, structured so work tickets can be extracted directly from §6 Entwicklungsetappen.
- **`references/`** — Midjourney moodboard images, referenced from `BALLON_GDD.md` §4. Treat as read-only; don't rename without updating the GDD image paths.

The design document is written in German. **Preserve German terminology** when editing — most terms are domain-specific (e.g. `Fernrohr`, `Korb`, `Propeller`, `Faden`) and not translatable labels.

---

## BALLON_GDD.md

### Document structure
1. Vision
2. Kernmechaniken (locked decisions)
3. Korb-Stationen (MVP baseline)
4. Moodboard & visuelle Richtung (with embedded images)
5. Offene Designfragen (unresolved)
6. Entwicklungsetappen (Godot 4, each Etappe is an epic, bullets are ticket candidates)
7. Vom Dokument zu Tickets (extraction rule)
8. Änderungshistorie

### Invariants when editing
- **Bump `$meta.version`** (SemVer; currently `0.2.0`) on any non-trivial edit, and add a dated line in §8 Änderungshistorie describing what changed.
- **Decisions live in §2 (mechanics) or §4.3 (visual).** Unresolved questions live in §5. When a question is resolved, *move* it — don't just delete it from §5.
- **§6 Entwicklungsetappen must stay runnable.** Every Etappe should leave something testable behind. Don't collapse multiple Etappen into a single dependency-heavy chunk.
- **Moodboard image paths** must resolve — all image refs point to `references/moodboard_NN_*.png`. If you rename or move images, update §4 refs in the same edit.

### Relevant skill
The project-scoped **`godot`** skill is the right tool for any implementation work. It provides Godot 4 templates, format knowledge (`.gd`, `.tscn`, `.tres`), common pitfalls, and CLI workflows. Use it when implementing any Etappe from §6 or validating Godot project state.

---

## Commands

No build, lint, or test setup yet. Validation helper:

```bash
# Check that all moodboard image refs in BALLON_GDD.md resolve
grep -oE 'references/[^)]+\.png' BALLON_GDD.md | sort -u | \
  while read -r f; do [ -f "$f" ] || echo "MISSING: $f"; done
```

Once the Godot 4 prototype starts, replace this section with engine version, run commands, and test commands.
