---
name: Phase 7 Release Polish
overview: "Complete v0.2 polish: implement the `read` primitive, attach source positions to all reader errors, document build/run/test in README, and update IMPLEMENTATION.md. Phase 8 (stdlib) deferred."
todos:
  - id: p7-read
    content: Add Reader.read_channel_line and read primitive in eval.ml; eval test
    status: completed
  - id: p7-reader-pos
    content: "Thread stream through desugar; Read_error for all read: errors; reader test"
    status: completed
  - id: p7-error-print
    content: Use read_error_message in main.ml and runner.ml
    status: completed
  - id: p7-docs
    content: Update README.md and IMPLEMENTATION.md (v0.2 complete); dune runtest passes
    status: completed
isProject: false
---

# Phase 7 — Polish + v0.2 Release

## Current state

Phase 6 committed ([cc29146](.)): conformance suite, `apply`, `treesp test`.

**Already in place:**
- [lib/eval.ml](lib/eval.ml) — `runtime.input` is `stdin` in `make_runtime`
- [lib/reader.ml](lib/reader.ml) — `Read_error of pos * string` for lexer/parser errors; `read_error_message` helper
- [bin/main.ml](bin/main.ml) — REPL prints `line`/`col` for `Read_error` on typed input
- [docs/TREESP.md](docs/TREESP.md) §7.8 lists `read` as conceptual I/O

**Gaps for v0.2:**
- `read` primitive **not implemented** (not in `primitive_names`)
- Desugar errors (`read: mixed branch forms`, duplicate label) raise `Treesp_error` **without position** — see [lib/reader.ml](lib/reader.ml) lines 153–170
- [README.md](README.md) has no build/run instructions
- v0.2 milestone in [IMPLEMENTATION.md](docs/IMPLEMENTATION.md) not marked complete

```mermaid
flowchart LR
  REPL[bin/main.ml] --> Eval[eval.ml]
  Eval --> ReadPrim["read primitive"]
  ReadPrim --> Input[runtime.input]
  Input --> Reader[Reader.read_one per line]
  Reader --> Desugar[desugar with pos]
```

---

## Scope

| In scope | Out of scope (Phase 8+) |
|----------|---------------------------|
| `read` primitive (§7.8) | `merge-branches`, `depth`, `size`, … |
| Reader desugar errors with positions | Eval-time source locations |
| README build/run/test docs | Git tag `v0.2` (only on explicit request) |
| Tests + IMPLEMENTATION.md update | Multi-line `read` / full s-exp scanner |

---

## 1. `read` primitive — [lib/eval.ml](lib/eval.ml)

Add `read` to `primitive_names` and `apply_prim`:

- Read **one line** from `rt.input` via `input_line` (v0.2 semantics: one REPL line = one datum; document in IMPLEMENTATION.md)
- Parse with `Reader.read_one line`
- On `End_of_file` → return `Void` (or raise `read: EOF` — prefer **Void** to match `()` / empty-input idiom; note in docs)
- On `Read_error` → re-raise (caller formats with position)

Add [lib/reader.ml](lib/reader.ml) helper:

```ocaml
val read_channel_line : in_channel -> value
(* input_line + read_one; EOF → End_of_file *)
```

Wire REPL to use the same path if useful (optional; REPL already calls `read_all` on `read_line` — keep as-is).

**Test** in [test/eval_test.ml](test/eval_test.ml): runtime with `input` set to a string channel (`In_channel.of_string "(+ 1 2)\n"`), `(read)` → `3.0`.

---

## 2. Reader error positions — [lib/reader.ml](lib/reader.ml)

Thread `stream` through `desugar_raw` / `desugar_compound` so desugar failures use `error st msg` (same as lexer), not `Treesp_error`.

Replace the four `Treesp_error "read: …"` sites in `desugar_compound` with `error st …`.

Update `read_one` / `read_all` call sites:

```ocaml
let read_one s =
  let st = make_stream s in
  let v = desugar_raw st (read_raw st) in
  ...
```

**Test** in [test/reader_test.ml](test/reader_test.ml): e.g. `(f (x 1) (y c d))` mixed-branch error is `Read_error` with `line = 1` and `col > 0`.

Standardize error printing:
- [bin/main.ml](bin/main.ml) and [lib/runner.ml](lib/runner.ml) use `Reader.read_error_message` for all reader failures

---

## 3. README — [README.md](README.md)

Add a **Getting started** section:

```bash
opam install . --deps-only   # or: dune pkg deps
dune build
dune exec treesp             # REPL
dune test                    # unit + conformance tests
dune exec treesp -- test     # §10 examples
```

Brief pointer to `docs/TREESP.md`, `docs/IMPLEMENTATION.md`, and `examples/`.

---

## 4. Documentation — [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md)

- `read` primitive: line-based, uses `runtime.input`, EOF → void
- Reader: all `read: …` errors carry line/column via `Read_error`
- Mark **v0.2 complete** in version milestones table

Optional one-line note in [docs/TREESP.md](docs/TREESP.md) §7.8: `read` reads one line (v0.2).

---

## 5. Verification

```bash
dune runtest          # 59+ tests green
dune exec treesp        # manual: (read) after typing a line in nested eval if tested via file
dune exec treesp -- test
```

**Gate:** all existing tests pass; new `read` + desugar-position tests pass.

Stop before Phase 8 unless you ask to continue.
