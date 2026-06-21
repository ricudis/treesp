# TREESP implementation plans

Archived copies of the Cursor plans used to build the reference interpreter (v0.1–v0.3). Originals live under `.cursor/plans/` in the editor config; these files are the project-local record.

## Roadmap and host

| Plan | Scope | Milestone |
|------|-------|-----------|
| [00-treesp-roadmap.plan.md](00-treesp-roadmap.plan.md) | Full phased roadmap (spec → interpreter → stdlib → editor) | — |
| [01-treesp-language-spec.plan.md](01-treesp-language-spec.plan.md) | Language specification (TREESP.md) | v0.1 |
| [02-treesp-ocaml-interpreter.plan.md](02-treesp-ocaml-interpreter.plan.md) | Master OCaml interpreter plan (Phases 0–8) | v0.2–v0.3 |

## Phases (implementation)

| Plan | Scope | Git tag |
|------|-------|---------|
| [phase-3-evaluator.plan.md](phase-3-evaluator.plan.md) | Evaluator, env, REPL | — (`ac49e91`) |
| [phase-4-tree-primitives.plan.md](phase-4-tree-primitives.plan.md) | Tree primitives, traversal, `node` | — (`0487c91`) |
| [phase-5-macros-match.plan.md](phase-5-macros-match.plan.md) | `let`/`cond`/`set!`/`match`, macros, quasiquote | — (`52b0b67`) |
| [phase-6-conformance.plan.md](phase-6-conformance.plan.md) | Conformance suite, `apply`, `treesp test` | — (`cc29146`) |
| [phase-7-release-polish.plan.md](phase-7-release-polish.plan.md) | `read`, reader error positions, docs | **v0.2** (`8105706`) |
| [phase-8-stdlib.plan.md](phase-8-stdlib.plan.md) | §9.5 stdlib helpers | **v0.3** (`e492005`) |

Phase 9 (editor) was explicitly deferred; see [INTRODUCTION.md](../INTRODUCTION.md).
