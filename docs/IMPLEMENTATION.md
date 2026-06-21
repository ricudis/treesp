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
| Rest parameters | **`(rest name)` in macro params** | Collects remaining call branches into a `begin` tree; enables `when` / `defun` |
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
- Reader classifies explicit vs positional branches from **raw S-expressions** before child desugaring (§4.2).

## Tree primitives

### `node` and positional calls

`node` is a **special form** (not a primitive). Surface forms like `(node expr (op +) (left 1))` use a bare tag atom, so the reader desugars the call positionally (§4.2). Evaluation rules:

- **Tag** (`arg0`): symbols and other atoms are literal (`eval-data`); compound expressions are evaluated.
- **Unary branch** (`argN` shaped as `(label value)`): the label comes from the subtree tag; **atoms** in the value position are literal, **compound trees** are fully evaluated (so nested `(node …)` works).
- Non-`argN` keys in the branch map are explicit labels; values are evaluated.
- Duplicate labels → error.

### Label arguments on primitives

For `graft`, `prune`, `branch`, `branch?`, and label steps of `path`, symbol arguments are **literal** (not looked up in the environment). Other arguments are evaluated normally.

**Lambda `(params (x) (y))`.** The reader desugars this positionally to `(params (arg0 (x)) (arg1 (y)))`; `param_labels` extracts `x` and `y` from the unary param subtrees.

### `walk-tree`

Pre-order: `pre-fn` on the current node, then each child in branch order, then `post-fn` on the current node. Returns void.

## Special forms (Phase 5)

### `let`, `cond`, `set!`, `match`

- **`let`** — bindings are parsed from the bindings tree: each binding is a unary `(name init)` subtree; a single `((x 10))` wrapper is accepted. When the reader desugars `((x 10) (y 20))` as an explicit-label tree (first binding as tag, rest as labeled branches), `let_bindings` still extracts all `(name init)` pairs. Initializers are evaluated in the outer environment; the body runs in an extended frame.
- **`cond`** — clauses are positional branches. A unary clause `(test expr)` uses the tag as the test expression. `else` as tag always matches.
- **`set!`** — `arg0` is a literal symbol (`eval-data`); `arg1` is evaluated; `Env.set` mutates the binding; returns `Void`.
- **`match`** — scrutinee is evaluated; clauses are tried in order. Each clause is a 2-branch `(pattern result)` or 3-branch `(pattern guard result)` tree. Patterns support atoms, `(?? var)`, positional `(tag p …)`, and labeled `(tag (l p) …)`. Guards must be truthy. No match → error.

A minimal **`error`** primitive is provided for match fallbacks (full stdlib deferred to v0.3).

### `quasiquote`

Implemented as a **special form** (not a macro) to avoid bootstrap circularity. `lib/quasiquote.ml` walks the template:

- atoms pass through unchanged
- `(unquote e)` → evaluate `e`
- `(unquote-splicing e)` → expand unquotes in `e`, then evaluate; result must be a tree; graft its branches into the parent; duplicate labels → error
- other trees → recurse into children

The reader treats `unquote` / `unquote-splicing` compounds as template markers, not explicit branch labels (so `,x` inside a template desugars to a proper `unquote` subtree rather than label `unquote`).

### Macros

```ocaml
callable =
  | Prim of string
  | Closure of { env; params; body }
  | Macro of { env; params; body }
```

- **`define-macro`** mirrors `define` (positional or function-shaped first branch).
- On call, after special-form dispatch: if the operator is a `Macro`, **`apply_macro`** binds parameters to **unevaluated** branch subtrees, evaluates the macro body in the macro's captured environment, then **`eval_expr`** re-evaluates the expanded tree in the caller environment (non-hygienic, per §8.2).
- **Rest parameters:** a param subtree `(rest name)` collects all remaining call branches into a synthetic `begin` tree. Enables prelude macros `when` and `defun`.

Prelude macros are installed in `make_runtime` via `Env.define` (not `load_string`) to avoid reader mixed-branch issues on macro bodies.

### `apply` (§7.9)

Surface primitive exposing §5.3 `apply`: `(apply operator args-tree)` evaluates `operator` to a callable, requires `args-tree` to be a tree, and dispatches on its branches as a normal call. See [TREESP.md](TREESP.md) §7.9.

### I/O — `read` (§7.8)

- **`read`** reads **one line** from `runtime.input` (stdin in the REPL), parses it with `Reader.read_one`, and returns the resulting value.
- **EOF** (empty input channel) returns `Void` (same idiom as `()`).
- **Parse errors** raise `Reader.Read_error` with line/column; the REPL and file runner format them via `Reader.read_error_message`.

## Reader errors (Phase 7)

All reader failures — lexer, parser, and desugar (`read: mixed branch forms`, `read: duplicate branch label`, etc.) — raise `Read_error of pos * string` with source line and column. Desugar passes the active `stream` into `desugar_raw` / `desugar_compound` so errors use the same `error st msg` helper as the lexer.

## Conformance suite (Phase 6)

- **[examples/](examples/)** — one `.treesp` program per spec §10 section, with `.treesp.expected` golden stdout.
- **[lib/runner.ml](lib/runner.ml)** — `run_file` / `run_program` with stdout capture (via `Printer.with_output_buffer`).
- **`dune runtest`** — `conformance_test.ml` compares each example to its golden file.
- **`treesp test [FILE …]`** — same checks from the CLI (`treesp record` regenerates `.expected` files).

Project root is discovered by walking up from the cwd for an `examples/` directory (or `TREESP_ROOT`).

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

| Version | Scope | Status |
|---------|-------|--------|
| v0.1 | Specification only | complete |
| v0.2 | Reference interpreter + conformance tests | **complete** |
| v0.3 | Standard library helpers (§9.5) | planned |
