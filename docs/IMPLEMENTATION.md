# TREESP Implementation Notes (v0.2)

This document records implementation decisions for the reference interpreter. The normative language definition remains in [TREESP.md](TREESP.md).

## Host

| Item | Choice |
|------|--------|
| Language | **OCaml** |
| Build | **dune** 3.x |
| Tests | **alcotest** |

## Resolved open questions (from spec §12)

| Topic | v0.2 decision | Rationale |
|-------|---------------|-----------|
| Scoping | **Lexical** | Matches closure semantics in §5.3; avoids surprise |
| Extra `argN` on user calls | **Error** | Catches arity mistakes early |
| Macro hygiene | **Non-hygienic** | Expansion evaluated in macro env, result re-evaluated in caller env per §8.2 |
| Rest parameters | **Deferred** | Use explicit `arg0`…`argN`; macro rest handled ad hoc |
| Errors | **Host exceptions** | String messages; no exception trees |
| Numeric tower | **IEEE 754 doubles** | Per spec §2.1 |
| Module system | **Deferred** | Single prelude environment |
| Editor | **Deferred** | See [INTRODUCTION.md](INTRODUCTION.md) counter-challenge |

## Runtime representation

```
value =
  | Void
  | Bool | Num | Str | Sym
  | Tree { tag, branches: (label × value) list }   ; insertion order preserved
```

- `()` reads as `Void`.
- `(tag)` with no branches is a `Tree` with zero branches (not void).
- Trees are **immutable**; `graft`/`prune` return copies.
- Symbols are interned strings.
- `display` always prints desugared `argN` form (allowed per §7.8).

## Environment

Environments are trees tagged `env` with symbol bindings as branches and an optional `parent` branch linking to the enclosing frame. Lookup walks `parent` for lexical scoping.

## Project layout

```
lib/     value, printer, reader, env, eval, quasiquote, stdlib
bin/     REPL and examples test runner
test/    unit and conformance tests
examples/  .treesp files from spec §10
```

## Version milestones

| Version | Scope |
|---------|-------|
| v0.1 | Specification only |
| v0.2 | Reference interpreter + conformance tests |
| v0.3 | Standard library helpers (§9.5) |
